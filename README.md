# startjack
A script to start jackd, load a few calf studio plugins, connect everything together. 

## WARNING !!!!!
This script is made for my own needs, and fit my own configuration.
It is unlikely that it will run "out of the box" for your config. Please study the script and make appropriate changes.

## First run
The first time it is invoked, the script needs to know what devices to use for capture and playback.

This can be determined with 
```
aplay --list-devices
```
```
**** List of PLAYBACK Hardware Devices ****
card 0: PCH [HDA Intel PCH], device 0: ALC887-VD Analog [ALC887-VD Analog]
  Subdevices: 0/1
  Subdevice #0: subdevice #0
card 0: PCH [HDA Intel PCH], device 1: ALC887-VD Digital [ALC887-VD Digital]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 1: CODEC [USB AUDIO  CODEC], device 0: USB Audio [USB Audio]
  Subdevices: 0/1
  Subdevice #0: subdevice #0
```

For example, I use a mixer connected to my PC via USB, so I'll use `card 1` in this example. I need to specify the name of that card, here it is `CODEC` (the name is between `card x:` and the description in brakets) : 

```
./startjack.sh --capture CODEC --playback CODEC
```

## Subsequent runs
After the first run, it no longer mandatory to specify the devices on the command line. They are stored in `${HOME}/.startjackrc`
