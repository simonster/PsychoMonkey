% PsychoMonkey
% Copyright (C) 2012 Simon Kornblith
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU Affero General Public License as
% published by the Free Software Foundation, either version 3 of the
% License, or (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Affero General Public License for more details.
% 
% You should have received a copy of the GNU Affero General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
