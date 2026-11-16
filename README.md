## AVR Assembly Stopwatch
An interrupt-driven stopwatch written entirely in AVR assembly for the ATmega328P (Arduino Uno + LCD keypad shield).
It counts minutes, seconds and hundredths of a second, displays them on a 16x2 LCD as MM:SS:DD, and is controlled with the shield's buttons.
<img width="955" height="260" alt="image" src="https://github.com/user-attachments/assets/3904adaa-779c-41cb-939c-b03547c83b5f" />

## Controls: 
RIGHT = start · UP = stop · DOWN = reset

## How it works
Timer1 runs in CTC mode with a 1024 prescaler and OCR1A = 155, which triggers an interrupt about every 10 ms.
The interrupt only sets a flag. The main loop waits for that flag, then reads the buttons, updates the time (hundredths -> seconds -> minutes) and redraws the LCD. Keeping the ISR this small means it keeps interrupt fast and simple.
All five buttons share one ADC pin through a resistor ladder, so each button is identified by the top 4 bits of the ADC reading. Digits are split with repeated subtraction and converted to ASCII for the display.
## Accuracy
The exact value for 10 ms would be 156.25 ticks, which isn't possible with an integer register. The simulator runs slower than real time, but testing on real hardware showed OCR1A = 155 was the most accurate.
## Build
Assemble main.asm together with printlib.inc and flash it to an Arduino Uno.

## Credits
Course assignment. Timer/ADC initialization and `printlib.inc` were provided by the course; the stopwatch logic, button handling, time counting and display formatting are my own.
