# Noise Shaker: Clap audio plugin written in Zig
* An audio plugin using the CLAP audio standard https://github.com/free-audio/clap
* Works on Windows/MacOS
  * verfied on Reaper

![image](https://user-images.githubusercontent.com/2457708/208302646-983719ee-6ebd-44a0-9cd0-630b9ec45ba9.png)
## Build
- Requires latest zig https://ziglang.org/download/
  - verified for version 0.11.0-dev.764+89a9e927a
- cd to directory
- run `%path to zig%/zig build`
  - cannot cross-compile
- clap plugin is in zig-out/lib

## Guide
Activate by holding any midi note

## Example
plain: https://user-images.githubusercontent.com/2457708/208301440-6a721d90-b1c1-465c-9853-0548227c3352.mp4

With high-pass filter: https://user-images.githubusercontent.com/2457708/208301507-7048fb69-a8f4-426a-a70b-5470c193bd2f.mp4

