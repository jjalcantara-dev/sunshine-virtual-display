#!/usr/bin/env python3
"""Generate a 3840x2160@60 Hz HDMI EDID for a virtual display.

The EDID describes a generic 16:9 4K TV: a base block with 4K60 and 1080p60
detailed timings, plus a CTA-861 extension with 4K60/4K30/1080p60/720p60/480p
VICs, stereo LPCM audio, and HDMI 1.4 + HDMI Forum VSDBs (600 MHz TMDS) so the
GPU driver accepts 4K60 over HDMI. It passes `edid-decode --check` cleanly.

Usage: gen_edid.py [output.bin]   (default: sunshine-4k60.bin)
"""
import struct
import sys


def dtd(pclk_khz, ha, hb, hso, hsw, va, vb, vso, vsw, hmm, vmm):
    """18-byte Detailed Timing Descriptor (digital separate sync, +H +V)."""
    p = pclk_khz // 10
    return bytes([
        p & 0xFF, p >> 8,
        ha & 0xFF, hb & 0xFF, ((ha >> 8) << 4) | (hb >> 8),
        va & 0xFF, vb & 0xFF, ((va >> 8) << 4) | (vb >> 8),
        hso & 0xFF, hsw & 0xFF, ((vso & 0xF) << 4) | (vsw & 0xF),
        ((hso >> 8) << 6) | ((hsw >> 8) << 4) | ((vso >> 4) << 2) | (vsw >> 4),
        hmm & 0xFF, vmm & 0xFF, ((hmm >> 8) << 4) | (vmm >> 8),
        0, 0, 0x1E,
    ])


def text_descriptor(tag, s):
    b = s.encode()[:13]
    if len(b) < 13:
        b += b'\n' + b' ' * (12 - len(b))
    return bytes([0, 0, 0, tag, 0]) + b


def manufacturer_id(s):
    v = ((ord(s[0]) - 64) << 10) | ((ord(s[1]) - 64) << 5) | (ord(s[2]) - 64)
    return struct.pack('>H', v)


def checksum(block):
    return (-sum(block)) & 0xFF


# CTA-861 timings: 3840x2160@60 (594 MHz) and 1920x1080@60 (148.5 MHz), 1210x680 mm
UHD60 = (594000, 3840, 560, 176, 88, 2160, 90, 8, 10, 1210, 680)
FHD60 = (148500, 1920, 280, 88, 44, 1080, 45, 4, 5, 1210, 680)


def build():
    base = bytearray(b'\x00\xff\xff\xff\xff\xff\xff\x00')
    base += manufacturer_id('SUN') + struct.pack('<H', 0x4B60) + struct.pack('<I', 0)
    base += bytes([1, 36, 1, 3])                     # week 1, 2026, EDID 1.3
    base += bytes([0x80, 121, 68, 0x78, 0x0E])      # digital, 121x68 cm, gamma 2.2, sRGB + preferred timing
    base += bytes([0xEE, 0x91, 0xA3, 0x54, 0x4C, 0x99, 0x26, 0x0F, 0x50, 0x54])  # sRGB chromaticity
    base += bytes([0x20, 0x00, 0x00]) + b'\x01\x01' * 8                         # 640x480@60, no standard timings
    base += dtd(*UHD60)
    base += dtd(*FHD60)
    base += bytes([0, 0, 0, 0xFD, 0, 24, 75, 15, 136, 60, 0, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20])  # range limits
    base += text_descriptor(0xFC, 'Sunshine 4K')
    base += bytes([1, 0])                            # one extension block, checksum placeholder
    base[127] = checksum(base[:127])

    blocks = bytes([0xE2, 0x00, 0x4A])               # VCDB: selectable RGB quantization, IT/CE underscanned
    blocks += bytes([0x45, 97, 95, 16, 4, 1])        # video: 4K60, 4K30, 1080p60, 720p60, 480p
    blocks += bytes([0x23, 0x09, 0x07, 0x07])        # audio: LPCM 2ch, 32/44.1/48 kHz, 16/20/24 bit
    blocks += bytes([0x83, 0x01, 0x00, 0x00])        # speaker allocation: FL/FR
    blocks += bytes([0x67, 0x03, 0x0C, 0x00, 0x10, 0x00, 0x00, 0x44])  # HDMI 1.4 VSDB, 340 MHz
    blocks += bytes([0x67, 0xD8, 0x5D, 0xC4, 0x01, 0x78, 0x80, 0x00])  # HDMI Forum VSDB, 600 MHz, SCDC
    ext = bytearray([0x02, 0x03, 4 + len(blocks), 0xC1]) + blocks  # underscan, basic audio, 1 native DTD
    ext += dtd(*UHD60)
    ext += bytes(127 - len(ext))
    ext.append(checksum(ext))
    return bytes(base + ext)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'sunshine-4k60.bin'
    with open(out, 'wb') as f:
        f.write(build())
    print(f'Wrote {out}')
