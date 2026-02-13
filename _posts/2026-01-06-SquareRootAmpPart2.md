---
layout: post
title: Computing square roots analog 
date: 2024-12-14
tags: 
    - Electronics
categories:
    - projects

permalink_name: /projects
---

# Introduction


# The circuit

![circuit diagram](/img/2026-01-06-SquareRootAmpPart2/WhatsApp Image 2026-01-05 at 18.32.21.jpeg)

This circuit consists of 4 stages, but the most important one are the first and last. The first is a logarithmic amplifier while the latter is an anti-log amp. The idea is that we take the log of the input voltage, scale it and then reverse the log to obtain the square root.

## First stage

Assuming the current across $R_1$ to be $I_1$:

$$I_1 = \frac{v_{in}}{R_1}$$

This current should be equal to the current through the collector of $Q_1$:

$$I_{C1} = I_s (e^{V_{BE1}/V_T} - 1) \approx I_s e^{V_{BE}/V_T}$$

This is the Ebers-moll model, and we can write that for any of the transistors the $V_{BE}$ is expressed as such. This is of course applicable since the exponential term is much larger than 1.

$$V_{BE} \approx V_T \log{\frac{I_C}{I_S}}$$

We can express the collector current of $Q_2$ as $I_2$. Then the mesh equation is:

$$V_{CC} = I_2 R_3 + V_{BE2} - V_{BE1}$$

There is another approximation we can make, since the voltage drop across $R_3$ is larger than any of the base-emitter voltages:

$$I_2 \approx \frac{V_{CC}}{R_3}$$

We now have enough information to determine the gain of this stage. The voltage at the base of $Q_2$, $v_2$ , can be expressed in order of $V_{BE1}$ and $V_{BE2}$:

$$v_2 = V_{BE2} - V_{BE1} \Leftrightarrow v_2 = V_T \log{\frac{I_2}{I_s}} - V_T \log{\frac{I_1}{I_s}} $$

$$v_2 = V_T \left( \log{\frac{V_{CC}}{R_3 I_s}} - \log{\frac{v_{in}}{R_1 I_s}} \right) = V_t \log{\frac{R_1 V_{cc}}{R_3 v_{in}}} $$

If we choose appropriate values for $R_1$, $R_3$ and $V_{CC}$, such that 

$$\frac{R_1 V_{CC}}{R_3} = 1$$

Then the gain becomes:

$$v_2 = -V_t \log{v_{in}} $$

### The star of the show - LM4036

So far I have been assuming that $I_s$ is the same across all transistors, which is a nice approximation that simplifies the circuit analysis. Regardless, in the real world, semiconductor fabrication processes are not deterministic and different transistor lots have different dynamic charecteristics. We can minimize the effect of mismatching by using a transistor array IC such as the LM4036.

## Second stage

The gain for the second stage is rather simple, as it is merely an opamp connected in a non-inverting configuration. If we take the output of $U_2$ as $v_3$, then:

$$v_3 = \left( \frac{R_5}{R_4} + 1 \right) v_2$$

Before hitting the final anti-log stage, there is a voltage divider between $v_3$ and $v_4$:

$$v_4 = \frac{R_B}{R_B + R_A} v_3$$

## Third stage

The first thing to note is that in this stage we also have a matched pair of transistors $Q_{3,4}$. We write the currents $I_3$ and $I_4$ across $Q_3$ and $Q_4$ as such:

$$I_3 = \frac{V_{cc}-v_4}{R_C} \approx \frac{V_{cc}}{R_C}$$

$$I_4 = \frac{v_o}{R_E}$$

The analysis is pretty much the same as for the log amp, where we can take the mesh equation for $v_4$:

$$v_4 = V_{BE3} - V_{BE4} \Leftrightarrow v_4 = V_t \left( \log{\frac{I_3}{I_s}} - \log{\frac{I_4}{I_s}} \right)$$

$$v_4 = V_t \left( \log{\frac{V_{cc}}{I_s R_C}} - \log{\frac{v_o}{I_s R_E}} \right) = V_t \log{\frac{I_s V_{cc} R_E}{I_s v_o R_C}}$$

If we choose the right values for $R_E$, $R_C$ and $V_{CC}$ we can greatly simplify the formula:

$$\frac{V_{CC} R_E}{R_C} = 1 \Rightarrow v_4 = -V_t \log{v_o}$$

The final gain can be obtained by multiplying all the individual stage gains and we obtain the formula:

$$v_o = v_{in}^{\frac{R_A}{R_A R_B} \left( \frac{R_5}{R_4}*1 \right)} $$

