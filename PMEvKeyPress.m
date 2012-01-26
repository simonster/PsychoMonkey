function f = PMEvKeyPress(keyCodes, blockUntilRelease)
%PMEvKeyPress Create keypress event
%   PMEvKeyPress(KEYCODES) creates a function whose that returns they keycode
%   of the key when one of the keys specified by KEYCODES has been pressed.
%   
%   PMEvKeyPress(KEYCODES, TRUE) acts as above, but the function blocks until
%   the key is released before returning.
if ~exist('blockUntilRelease', 'var')
    blockUntilRelease = false;
end

function isFinished = innerFunction()
    isFinished = false;
    [keyDown, ~, keyCode] = KbCheck();
    if keyDown
        codesOn = keyCode(keyCodes);
        if any(codesOn)
            isFinished = keyCodes(find(codesOn, 1));
            
            if blockUntilRelease
                while true
                    [~, ~, keyCode] = KbCheck();
                    if ~any(keyCode(keyCodes))
                        return;
                    end
                end
            end
        end
    end
end

f = @innerFunction;
end