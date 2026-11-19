package main

import (
	"encoding/binary"
	"fmt"
	"log"
	"os"
	"path/filepath"
)

type iconDirEntry struct {
	Width       byte
	Height      byte
	ColorCount  byte
	Reserved    byte
	Planes      uint16
	BitCount    uint16
	BytesInRes  uint32
	ImageOffset uint32
}

func main() {
	sizes := []int{16, 32, 48, 64, 128, 256}
	var pngDatas [][]byte

	for _, s := range sizes {
		pngPath := filepath.Join("assets", "images", fmt.Sprintf("logo_%d.png", s))
		data, err := os.ReadFile(pngPath)
		if err != nil {
			log.Fatalf("Failed to read %s: %v", pngPath, err)
		}
		pngDatas = append(pngDatas, data)
	}

	outPath := filepath.Join("windows", "runner", "resources", "app_icon.ico")
	f, err := os.Create(outPath)
	if err != nil {
		log.Fatalf("Failed to create ico: %v", err)
	}
	defer f.Close()

	// Write ICONDIR header (6 bytes)
	_ = binary.Write(f, binary.LittleEndian, uint16(0)) // Reserved
	_ = binary.Write(f, binary.LittleEndian, uint16(1)) // Type (1 = Icon)
	_ = binary.Write(f, binary.LittleEndian, uint16(len(sizes)))

	offset := uint32(6 + 16*len(sizes))
	entries := make([]iconDirEntry, len(sizes))

	for i, s := range sizes {
		w := byte(s)
		h := byte(s)
		if s == 256 {
			w = 0
			h = 0
		}
		entries[i] = iconDirEntry{
			Width:       w,
			Height:      h,
			ColorCount:  0,
			Reserved:    0,
			Planes:      1,
			BitCount:    32,
			BytesInRes:  uint32(len(pngDatas[i])),
			ImageOffset: offset,
		}
		offset += uint32(len(pngDatas[i]))
	}

	for _, entry := range entries {
		_ = binary.Write(f, binary.LittleEndian, entry)
	}

	for _, data := range pngDatas {
		_, _ = f.Write(data)
	}

	fmt.Printf("Successfully generated %s with %d sizes!\n", outPath, len(sizes))
}
