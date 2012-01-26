function pixels = PMAngleToPixels(angle)
global CONFIG;
pixels = 2*CONFIG.displayDistance*tand(angle/2)*(CONFIG.displaySize(1)/CONFIG.displayWidth);