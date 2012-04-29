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

function f = PMEvKeyPress(keys, blockUntilRelease)
%PMEvKeyPress Create keypress event
%   PMEvKeyPress(KEYS) creates a function whose that returns they keycode
%   or name of the key when one of the keys specified by KEYS has been
%   pressed. KEYS may be either a vector of PTB keyscan codes, in which
%   case a keyscan code is returned, or a cell array of keynames or a
%   struct whose keys are the key names, in which case a name is returned.
%   If KEYS is a struct, then it is used for the keyInfo parameter on the
%   OSD.
%   
%   PMEvKeyPress(KEYS, TRUE) acts as above, but the function blocks until
%   the key is released before returning.
global PM;

if ~exist('blockUntilRelease', 'var')
    blockUntilRelease = false;
end

if isstruct(keys)
    PM.osd.keyInfo = keys;
    keyCodes = fieldnames(keys);
end

if iscellstr(keys)
    keyCodes = KbName(keys);
    keyNames = upper(keys);
elseif isnumeric(keys)
    keyCodes = keys;
    keyNames = upper(KbName(keys));
else
    error('Invalid input');
end

function isFinished = innerFunction()
    isFinished = false;
    [keyDown, ~, keysPressed] = KbCheck();
    if keyDown
        codesOn = keysPressed(keyCodes);
        if any(codesOn)
            isFinished = keys(find(codesOn, 1));
            if iscell(isFinished)
                isFinished = isFinished{1};
            end
            
            if blockUntilRelease
                while true
                    [~, ~, keysPressed] = KbCheck();
                    if ~any(keysPressed(keyCodes))
                        return;
                    end
                end
            end
        end
    elseif isfield(PM, 'server')
        keysPressed = PM.server.getPressedKeys();
        tf = ismember(keyNames, keysPressed);
        isFinished = keys(find(tf, 1));
        if iscell(isFinished)
            isFinished = isFinished{1};
        end
    end
end

f = @innerFunction;
end
