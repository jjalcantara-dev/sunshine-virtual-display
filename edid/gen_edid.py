#!/usr/bin/env python3
"""Generate an HDMI EDID for a virtual display used as a Sunshine streaming target.

The EDID describes a generic 16:9 4K TV (preferred mode 3840x2160@60) that also
offers the resolutions Moonlight clients commonly ask for, so the stream can match
the client exactly:

    3840x2160 @ 60, 30        (CTA VIC 97, 95; 4K60 is also the preferred DTD)
    2560x1440 @ 120, 60       (CVT reduced blanking DTDs)
    1920x1200 @ 60            (CVT-RB DTD, 16:10)
    1920x1080 @ 120, 60       (CTA VIC 63, 16)
    1280x800  @ 60            (CVT-RB DTD, 16:10, e.g. Steam Deck)
    1280x720  @ 60, 640x480   (CTA VIC 4, 1)

Every mode fits within HDMI 2.0 (<= 600 MHz TMDS); the HDMI 1.4 and HDMI Forum
VSDBs advertise 600 MHz so the GPU driver accepts 4K60 over HDMI.
It passes `edid-decode --check` cleanly.

Usage: gen_edid.py [output.bin]   (default: sunshine-4k60.bin)
"""
import struct
import sys


def dtd(pclk_khz, ha, hb, hso, hsw, va, vb, vso, vsw, hmm, vmm, flags=0x1E):
    """18-byte Detailed Timing Descriptor. flags 0x1E: digital separate sync +H +V; 0x1A: +H -V (CVT-RB)."""
    p = pclk_khz // 10
    return bytes([
        p & 0xFF, p >> 8,
        ha & 0xFF, hb & 0xFF, ((ha >> 8) << 4) | (hb >> 8),
        va & 0xFF, vb & 0xFF, ((va >> 8) << 4) | (vb >> 8),
        hso & 0xFF, hsw & 0xFF, ((vso & 0xF) << 4) | (vsw & 0xF),
        ((hso >> 8) << 6) | ((hsw >> 8) << 4) | ((vso >> 4) << 2) | (vsw >> 4),
        hmm & 0xFF, vmm & 0xFF, ((hmm >> 8) << 4) | (vmm >> 8),
        0, 0, flags,
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


# (pixel clock kHz, h active, h blank, h sync offset, h sync width,
#  v active, v blank, v sync offset, v sync width, width mm, height mm, flags)
UHD60 = (594000, 3840, 560, 176, 88, 2160, 90, 8, 10, 1210, 680)            # CTA-861 VIC 97
QHD60 = (241500, 2560, 160, 48, 32, 1440, 41, 3, 5, 1210, 680, 0x1A)        # CVT-RB, 59.95 Hz
QHD120 = (497750, 2560, 160, 48, 32, 1440, 85, 3, 5, 1210, 680, 0x1A)       # CVT-RB, 120.00 Hz
WUXGA60 = (154000, 1920, 160, 48, 32, 1200, 35, 3, 6, 1088, 680, 0x1A)      # CVT-RB, 59.95 Hz
WXGA60 = (71000, 1280, 160, 48, 32, 800, 23, 3, 6, 1088, 680, 0x1A)         # CVT-RB, 59.91 Hz


def build():
    base = bytearray(b'\x00\xff\xff\xff\xff\xff\xff\x00')
    base += manufacturer_id('SUN') + struct.pack('<H', 0x4B60) + struct.pack('<I', 0)
    base += bytes([1, 36, 1, 3])                     # week 1, 2026, EDID 1.3
    base += bytes([0x80, 121, 68, 0x78, 0x0E])      # digital, 121x68 cm, gamma 2.2, sRGB + preferred timing
    base += bytes([0xEE, 0x91, 0xA3, 0x54, 0x4C, 0x99, 0x26, 0x0F, 0x50, 0x54])  # sRGB chromaticity
    base += bytes([0x20, 0x00, 0x00]) + b'\x01\x01' * 8                         # 640x480@60, no standard timings
    base += dtd(*UHD60)                              # preferred timing
    base += dtd(*QHD60)
    # range limits: 24-120 Hz vertical, 15-185 kHz horizontal, 600 MHz max pixel clock
    base += bytes([0, 0, 0, 0xFD, 0, 24, 120, 15, 185, 60, 0, 0x0A, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20])
    base += text_descriptor(0xFC, 'Sunshine 4K')
    base += bytes([1, 0])                            # one extension block, checksum placeholder
    base[127] = checksum(base[:127])

    blocks = bytes([0xE2, 0x00, 0x4A])               # VCDB: selectable RGB quantization, IT/CE underscanned
    blocks += bytes([0x46, 97, 95, 63, 16, 4, 1])    # video: 4K60, 4K30, 1080p120, 1080p60, 720p60, 480p
    blocks += bytes([0x23, 0x09, 0x07, 0x07])        # audio: LPCM 2ch, 32/44.1/48 kHz, 16/20/24 bit
    blocks += bytes([0x83, 0x01, 0x00, 0x00])        # speaker allocation: FL/FR
    blocks += bytes([0x67, 0x03, 0x0C, 0x00, 0x10, 0x00, 0x00, 0x44])  # HDMI 1.4 VSDB, 340 MHz
    blocks += bytes([0x67, 0xD8, 0x5D, 0xC4, 0x01, 0x78, 0x80, 0x00])  # HDMI Forum VSDB, 600 MHz, SCDC
    ext = bytearray([0x02, 0x03, 4 + len(blocks), 0xC1]) + blocks  # underscan, basic audio, 1 native DTD
    ext += dtd(*QHD120) + dtd(*WUXGA60) + dtd(*WXGA60)
    ext += bytes(127 - len(ext))
    ext.append(checksum(ext))
    return bytes(base + ext)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'sunshine-4k60.bin'
    with open(out, 'wb') as f:
        f.write(build())
    print(f'Wrote {out}')
