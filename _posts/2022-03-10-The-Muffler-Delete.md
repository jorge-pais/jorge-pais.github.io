---
layout: post
title: DIY MIDI Controller
date: 2022-03-10
tags: 
    - Music
    - Electronics
categories:
    - projects
---

<!-- # The Muffler Delete -->

# Introduction

The Big Muff (π) is a fuzz/distortion effect pedal that has since the 1970s been one of the most influential guitar effects, being adopted by all sorts of musical genres and beloved by musicians worldwide. Originally the circuit was developed by Robert Myer of Bell Labs along with Mike Matthews of Electro-Harmonix, and the first units of the pedal were released in early 1969. 

![http://www.kitrae.net/music/Images_Secret_Music_Page/IMG_4757.jpg](http://www.kitrae.net/music/Images_Secret_Music_Page/IMG_4757.jpg)

Nowadays Electro-Harmonix still sells the Big Muff and there have been several variations of the circuit throughout the years. Other effect pedal companies have also released their versions and interpretations of the Big Muff with their own modifications.

This article I’ll introduce the circuit and the parts which constitute it, and design and layout my out version, along with a PCB. 

# The Big Muff Circuit

The following circuit is from a 72’ Triangle Big Muff, regarded by many players as one of the best sounding variations of the pedal:

![Untitled](The%20Muffle%20c048b/Untitled.png)

The circuit can be logically divided into 5 distinct sections, the input stage, the first and second clipping stages, the tone stack and the output stage.

### The input stage

Before we can do anything to the signal coming from the guitar, we need to amplify it given that usually the signal from a guitar is of high impedance. This is done by the input stage which is shown as follows: 

![Untitled](The%20Muffle%20c048b/Untitled%201.png)

It is essentially a common emitter with series-shunt feedback amplifier, which provides better voltage gain stability, better frequency response and improved linearity when compared to a simple common emitter amplifier. R6 and R7 represent a 100kOhm linear potentiometer, which determine how much of the amplified signal passes on to the subsequent stage. Capacitor C1 forms a high pass filter and C2 is a miller capacitor forming a low pass filter while also preventing oscillation.

### The clipping stages

After getting amplified the actual distortion is achieved through the clipping stage. Each of the stages is almost identical to the input stage, the only difference being the diodes in the feedback loop. These will [‘clip’](https://en.wikipedia.org/wiki/Clipping_(signal_processing)?oldformat=true) the signal when a certain voltage threshold is reached, this is also referred to as soft clipping. The two copies of the circuit will guarantee that the desired effect is produced, if there was only one of these stages the big muff would sound more ‘overdrivy’.

![Untitled](The%20Muffle%20c048b/Untitled%202.png)

Replacing the clipping diodes on a Big Muff is a quick and easy way to change the way the pedal sounds.

### The tonestack

After clipping the signal the tone stack is responsible for modifying the frequency content of the sound. The circuit is essentially mixture of a low-pass and a high-pass filter, resulting in the famous ‘mid-scoop’ that the Big Muff is known for.

![Untitled](The%20Muffle%20c048b/Untitled%203.png)

C10 and R22 form an high-pass filter, and C11 and R19 for a low-pass filter, while R20 and R21 represent the 100kOhm linear potentiometer controlling the blend of both filters

### The output stage

Finally the signal is amplified once again before leaving the pedal. The output stage consists of a simple common emitter amplifier and a potentiometer (a 100k lin. pot. once again, represented by R27 and R28).

![Untitled](The%20Muffle%20c048b/Untitled%204.png)

# Deleting the Muffler

Although the pedal is great by itself, many players usually will have a booster pedal alongside it while playing live, and engaging said booster during solo sections to allow their solo to ‘cut through the mix’. It this in mind I sketched out the following schematic in KiCad: 

![https://user-images.githubusercontent.com/70813514/156430954-624521ef-dc38-42bb-966f-062b9164a765.png](https://user-images.githubusercontent.com/70813514/156430954-624521ef-dc38-42bb-966f-062b9164a765.png)

I also added a DPDT switch to change the clipping diodes from a the usual silicon ones to LEDs. The PCB also designed in KiCad:

![https://user-images.githubusercontent.com/70813514/156431114-f36bfcc2-6494-457e-acde-719c579c7105.png](https://user-images.githubusercontent.com/70813514/156431114-f36bfcc2-6494-457e-acde-719c579c7105.png)

![https://user-images.githubusercontent.com/70813514/156431423-93650aa1-cfdb-416e-a4b2-3601d4135076.png](https://user-images.githubusercontent.com/70813514/156431423-93650aa1-cfdb-416e-a4b2-3601d4135076.png)

I left the Big Muff circuit and the Linear Power Booster wiring separated to allow more flexible wiring schemes. 
