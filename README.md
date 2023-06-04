# TamperMod
Tampermonkey for the ModDuo (classic or X) - volume management &amp; more

Has been developped in particular on version: 1.7.4 of the Mod Duo X (2019-10-06), 2023-06-01 being updated for ModDwarf
For more information on the Hardware: https://www.moddevices.com/
For the time being very personal effort, probably hard to use by anybody else

** ui
 . bpm is red boxed for 5 seconds after system fetches it
 . middle click of the mouse (other buttons are already in use...)
 . 0 - select volume with code Digit0

** flow
 . overload of the click event

** objects
volumes
 . object of all volume pedals
 . pedals_families[volume] and volume are the basis of an instrument (also stored in instruments under volume.code)
loopers
Instrument
 . instruments have section and continuo properties
 . instruments need to be updated after a section or continuo change
Section
 . a section is empty (for a specific continuo) if no instruments has this section and continuo set
Continuo

** tools
 . investigationOfModPorts: 


* Todo
. reflect bpm value in UI (easier to notice if there's an update issue)