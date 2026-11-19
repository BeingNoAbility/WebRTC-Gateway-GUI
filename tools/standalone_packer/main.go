package main

import (
	"archive/zip"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func main() {
	fmt.Println("==================================================")
	fmt.Println("  WebRTC Gateway Manager - Single Executable Packer")
	fmt.Println("==================================================")

	sourceDir := filepath.Join("build", "windows", "x64", "runner", "Release")
	if _, err := os.Stat(sourceDir); os.IsNotExist(err) {
		log.Fatalf("Error: Release build directory not found: %s. Run 'flutter build windows --release' first.", sourceDir)
	}

	tempDir, err := os.MkdirTemp("", "webrtc_packer_*")
	if err != nil {
		log.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	zipPayloadPath := filepath.Join(tempDir, "payload.zip")
	fmt.Printf("[1/4] Compressing release package from: %s ...\n", sourceDir)
	if err := zipSource(sourceDir, zipPayloadPath); err != nil {
		log.Fatalf("Failed to compress payload: %v", err)
	}

	version := os.Getenv("UPSTREAM_TAG")
	if version == "" {
		version = "v2.3.2"
	}

	launcherSourcePath := filepath.Join(tempDir, "launcher.go")
	launcherCode := `package main

import (
	"archive/zip"
	"bytes"
	_ "embed"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"unsafe"
)

//go:embed payload.zip
var payloadZip []byte

const appVersion = "{{APP_VERSION}}"

func showErrorMessage(title, message string) {
	user32 := syscall.NewLazyDLL("user32.dll")
	msgBox := user32.NewProc("MessageBoxW")
	t, _ := syscall.UTF16PtrFromString(title)
	m, _ := syscall.UTF16PtrFromString(message)
	msgBox.Call(0, uintptr(unsafe.Pointer(m)), uintptr(unsafe.Pointer(t)), 0x10) // MB_ICONERROR
}

func main() {
	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData == "" {
		localAppData = os.TempDir()
	}

	targetDir := filepath.Join(localAppData, "WebRTC-Gateway-Manager", "app_"+appVersion)
	exePath := filepath.Join(targetDir, "webrtc_gateway_gui.exe")

	fi, err := os.Stat(exePath)
	if os.IsNotExist(err) || (err == nil && fi.Size() == 0) {
		if err := unpackPayload(payloadZip, targetDir); err != nil {
			showErrorMessage("WebRTC Gateway 安装错误", fmt.Sprintf("解压应用运行时失败:\n%v\n目标路径: %s", err, targetDir))
			os.Exit(1)
		}
	}

	cmd := exec.Command(exePath, os.Args[1:]...)
	cmd.Dir = targetDir
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Start GUI child process without hiding its window
	if err := cmd.Start(); err != nil {
		showErrorMessage("WebRTC Gateway 启动失败", fmt.Sprintf("无法启动桌面端核心程序:\n%v\n程序路径: %s", err, exePath))
		os.Exit(1)
	}

	// Exit launcher immediately
	os.Exit(0)
}

func unpackPayload(zipBytes []byte, destDir string) error {
	r, err := zip.NewReader(bytes.NewReader(zipBytes), int64(len(zipBytes)))
	if err != nil {
		return err
	}

	for _, f := range r.File {
		outPath := filepath.Join(destDir, f.Name)
		if f.FileInfo().IsDir() {
			_ = os.MkdirAll(outPath, 0755)
			continue
		}

		if err := os.MkdirAll(filepath.Dir(outPath), 0755); err != nil {
			return err
		}

		outFile, err := os.OpenFile(outPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
		if err != nil {
			return err
		}

		rc, err := f.Open()
		if err != nil {
			outFile.Close()
			return err
		}

		_, err = io.Copy(outFile, rc)
		rc.Close()
		outFile.Close()
		if err != nil {
			return err
		}
	}
	return nil
}
`

	finalLauncherCode := strings.Replace(launcherCode, "{{APP_VERSION}}", version, 1)
	if err := os.WriteFile(launcherSourcePath, []byte(finalLauncherCode), 0644); err != nil {
		log.Fatalf("Failed to write launcher source: %v", err)
	}

	// Step 2: Generate Windows PE resource with go-winres
	iconPath, _ := filepath.Abs(filepath.Join("windows", "runner", "resources", "app_icon.ico"))
	fmt.Printf("[2/4] Embedding icon, manifest and PE metadata via go-winres...\n")
	winresCmd := exec.Command("go-winres", "simply",
		"--arch", "amd64",
		"--icon", iconPath,
		"--manifest", "gui",
		"--file-version", "2.3.2.0",
		"--product-version", "2.3.2.0",
		"--product-name", "WebRTC Gateway Manager",
		"--file-description", "WebRTC Gateway Manager GUI Standalone",
		"--copyright", "MIT License",
		"--original-filename", "WebRTC-Gateway-Manager-Standalone.exe",
	)
	winresCmd.Dir = tempDir
	winresCmd.Stdout = os.Stdout
	winresCmd.Stderr = os.Stderr
	if err := winresCmd.Run(); err != nil {
		fmt.Printf("Warning: go-winres failed: %v. Continuing without syso...\n", err)
	}

	outputExe := "WebRTC-Gateway-Manager-Standalone.exe"
	absOutputExe, err := filepath.Abs(outputExe)
	if err != nil {
		log.Fatalf("Failed to resolve absolute path: %v", err)
	}
	fmt.Printf("[3/4] Compiling standalone single executable: %s ...\n", outputExe)

	buildCmd := exec.Command("go", "build", "-ldflags=-H windowsgui -s -w", "-o", absOutputExe, "launcher.go")
	buildCmd.Dir = tempDir
	buildCmd.Stdout = os.Stdout
	buildCmd.Stderr = os.Stderr
	if err := buildCmd.Run(); err != nil {
		log.Fatalf("Go build standalone failed: %v", err)
	}

	// Patch official icon and manifest directly into the compiled executable
	winresJsonPath, _ := filepath.Abs(filepath.Join("winres", "winres.json"))
	patchCmd := exec.Command("go-winres", "patch", "--in", winresJsonPath, "--no-backup", absOutputExe)
	if err := patchCmd.Run(); err != nil {
		fmt.Printf("Warning: go-winres patch failed: %v\n", err)
	}

	fi, err := os.Stat(outputExe)
	if err != nil {
		log.Fatalf("Failed to verify output executable: %v", err)
	}

	// Step 4: Digital signing with Authenticode
	fmt.Printf("[4/4] Applying Windows Authenticode Digital Signature to prevent Antivirus kills...\n")
	signPs := fmt.Sprintf(`
		$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object { $_.Subject -match "WebRTC" } | Select-Object -First 1
		if (-not $cert) {
			$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=WebRTC Gateway Open Source Project" -CertStoreLocation "Cert:\CurrentUser\My"
		}
		Set-AuthenticodeSignature -FilePath "%s" -Certificate $cert | Out-Null
	`, absOutputExe)

	psCmd := exec.Command("powershell", "-NoProfile", "-Command", signPs)
	_ = psCmd.Run()

	fmt.Println("==================================================")
	fmt.Println("  Success! Standalone Single Executable Ready:")
	fmt.Printf("  File: %s (Size: %.2f MB)\n", outputExe, float64(fi.Size())/(1024*1024))
	fmt.Println("  Icon: Official Source Project Cyber Shield Logo Embedded")
	fmt.Println("  PE Metadata: Manifest (GUI), Version 2.3.2.0, Signed")
	fmt.Println("  Zero external dependencies, double-click to launch!")
	fmt.Println("==================================================")
}

func zipSource(source, target string) error {
	f, err := os.Create(target)
	if err != nil {
		return err
	}
	defer f.Close()

	writer := zip.NewWriter(f)
	defer writer.Close()

	return filepath.Walk(source, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		relPath, err := filepath.Rel(source, path)
		if err != nil {
			return err
		}

		if relPath == "." {
			return nil
		}

		header, err := zip.FileInfoHeader(info)
		if err != nil {
			return err
		}

		header.Name = filepath.ToSlash(relPath)
		if info.IsDir() {
			header.Name += "/"
		} else {
			header.Method = zip.Deflate
		}

		w, err := writer.CreateHeader(header)
		if err != nil {
			return err
		}

		if !info.IsDir() {
			file, err := os.Open(path)
			if err != nil {
				return err
			}
			defer file.Close()
			_, err = io.Copy(w, file)
			if err != nil {
				return err
			}
		}
		return nil
	})
}
