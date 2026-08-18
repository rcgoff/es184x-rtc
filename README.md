# es184x-rtc
Real-time clock driver for ES-1840/41.

This driver is written for common DS1307/DS3231 I2C Arduino module,
piggy-backed on ES1840/41 8255 (KR580VV55A) chip.

The driver is notably small (less than 1024 bytes).

To be more precise, it is not a "driver" in the usual sense,
just a small tool able to read date/time from the RTC chip
and write it to DOS on startup or, conversely,
read date/time from DOS and write it to the RTC chip.

The tool returns DOS `ERRORLEVEL` codes and one can arrange its
`autoexec.bat` so that, if RTC chip is present 
(`ERRORLEVEL 0`) date/time is read from it, and if RTC isn't
present (`ERRORLEVEL >0`) - user is prompted to type date/time
manually.

The tool also checks whether the RTC clock is running; if not, it returns `ERRORLEVEL >0`.

Since I2C interface on 8255 can be implemented in inverted or
non-inverted manner (it depends on what chip is used:
8255 or 82c55, and what kind of buffer is used too, or 
no buffer), there are 2 versions of I2C backend:
inverted or non-inverted. So there are 2 makefiles and 2 executables.

Listings were prettified by a special in-house tool.

## Usage

```bat
DS1307 /todos   (or DS1307I /todos)
DS1307 /fromdos (or DS1307I /fromdos)
```

- `/todos`   - get date/time from RTC chip
- `/fromdos` - put date/time to RTC chip (set DOS date/time first).

DS1307 is the non-inverted version, DS1307I is the inverted one.

## Building

For building, MASM 4.0 and DOSBox were used. 
Earlier MASM versions unfortunately don't support `/D` and `/I` switches.

Make sure you have the full MASM toolchain: MASM, MAKE, LINK, EXE2BIN.

```bat
BUILD_NI - build non-inverting version
BUILD_I - build inverting version
```


Enjoy!
