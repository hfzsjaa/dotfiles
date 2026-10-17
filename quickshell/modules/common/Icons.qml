pragma Singleton

import Quickshell

Singleton {
    function glyph(code) {
        return String.fromCodePoint(code)
    }

    readonly property string music: glyph(0xF075A)
    readonly property string dashboard: glyph(0xF056E)

    readonly property string barNotch: glyph(0xF0131)
    readonly property string barDynamic: glyph(0xF0130)

    readonly property string volumeHigh: glyph(0xF057E)
    readonly property string volumeMedium: glyph(0xF0580)
    readonly property string volumeLow: glyph(0xF057F)
    readonly property string volumeMute: glyph(0xF075F)

    readonly property string wifi: glyph(0xF05A9)
    readonly property string ethernet: glyph(0xF0200)
    readonly property string netOff: glyph(0xF05AA)

    readonly property string bluetooth: glyph(0xF00AF)
    readonly property string bluetoothOff: glyph(0xF00B2)
    readonly property string nightLight: glyph(0xF0594)

    readonly property string chevronLeft: glyph(0xF0141)
    readonly property string chevronRight: glyph(0xF0142)

    readonly property string mediaPrev: glyph(0xF04AE)
    readonly property string mediaNext: glyph(0xF04AD)
    readonly property string mediaPlay: glyph(0xF040A)
    readonly property string mediaPause: glyph(0xF03E4)

    readonly property string cpu: glyph(0xF061A)
    readonly property string memory: glyph(0xF035B)

    function volume(audio) {
        if (audio && audio.volume < 0.34)
            return volumeLow
        if (audio && audio.volume < 0.67)
            return volumeMedium
        return volumeHigh
    }
}
