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

function paradigm(sessionName)

%% Define configuration options
global CONFIG;
CONFIG = struct();
% # of the main (task) display
CONFIG.mainDisplay = 2;
% # of the auxiliary (info) display
CONFIG.auxDisplay = 1;
% Height in pixels of region of auxiliary display to use for info display
CONFIG.OSDHeight = 150;
% Distance from the animal to the main display, in cm
CONFIG.displayDistance = 55;
% Width of the main display, in cm
CONFIG.displayWidth = 41;
% Radius of the fixation dot, in degrees
CONFIG.fixationPointRadius = 0.1;
% Radius around the fixation dot for fixation, in degrees
CONFIG.fixationRadius = 3;
% Offset for targets, in degrees
CONFIG.targetOffset = 6;
% Image width, in degrees
CONFIG.imageWidth = 4;
% Background color of the screen
CONFIG.backgroundColor = 0;

% DAQ adaptor name
CONFIG.daqAdaptor = 'nidaq';
% DAQ adaptor ID
CONFIG.daqID = 'Dev2';
% Input type. I think this will always be SingleEnded.
CONFIG.daqInputType = 'SingleEnded';
% Analog sample rate in Hz. If using the motion detector, this should be at
% least 10000. If not, 1000 is typically a good value.
CONFIG.analogSampleRate = 10000;
% The channels on the DAQ dedicated to the eye signal
CONFIG.channelsEye = [0 1];
% The channels on the DAQ dedicated to the motion sensor, or the empty set
% if no motion sensor
CONFIG.channelsMotion = 4;
% The (digital) channel on the DAQ dedicated to juice
CONFIG.channelJuice = 8;
% The motion threshold, in volts
CONFIG.motionThreshold = 0.5;
% Use iscan interface
CONFIG.eyeTracker = PMEyeISCAN();
%CONFIG.eyeTracker = PMEyeSim([5 5; 0 0; -2 0; 2 0]);

% Time penalty for motion (seconds)
CONFIG.timeoutMotion = 5;
% Time penalty for losing fixation
CONFIG.timeoutFixationLost = 0;
% Juice given manually (seconds)
CONFIG.juiceManual = 150e-3;
% Juice given for a correct response (seconds)
CONFIG.juiceTimeCorrect = 150e-3;
CONFIG.juiceBetweenCorrect = 20e-3;
CONFIG.juiceRepsCorrect = 3;

% Eccentricity of the dots on the screen, in degrees
CONFIG.dotEccentricity = 4;
% The amount of time the dot is on for
CONFIG.dotTime = 5500e-3;
% Reward given
CONFIG.dotRewardTime = 2000e-3;

%% Define states and keycodes
STATE_END = 0;
STATE_CALIBRATE = 1;
STATE_MANUAL = 2;
STATE_AUTO = 3;
STATE_BEGIN = STATE_MANUAL;

KEY_HORIZONTAL = 72;
KEY_VERTICAL = 86;
KEY_ALL = 65;
KEY_MODE = 77;
KEY_CENTER = 67;
KEY_LEFT = 37;
KEY_RIGHT = 39;
KEY_UP = 38;
KEY_DOWN = 40;
KEY_JUICE = 74;
KEY_QUIT = 27;

%% Initialization
PMInit();

% Initialize performance info for OSD
CONFIG.osd.performance = struct(...
    'Success', [0 0] ...
);

% Set up session data information
if ~exist('sessionName', 'var')
    sessionName = ['Session ' datestr(now, 'yyyy-mm-dd HHMMSS')];
end

datafile = [sessionName '.mat'];
if exist(datafile, 'file')
    sessionData = load(datafile);
    sessionData.time = [sessionData.time; now Inf];
else
    sessionData = struct(...
        'sessionName', sessionName, ...
        'time', [now Inf], ...
        'events', zeros(10000, 2), ...
        'nEvents', 0, ...
        'CONFIG', rmfield(CONFIG, {'daq', 'osd', 'eyeTracker'}) ...
    );
end

% Initialize performance info for OSD
CONFIG.osd.performance = struct(...
    'Left', [0 0], ...
    'Right', [0 0] ...
);
CONFIG.osd.keyInfo = struct();

% Set up session data information
if ~exist('sessionName', 'var')
    sessionName = ['Session ' datestr(now, 'yyyy-mm-dd HHMMSS')];
end

datafile = [sessionName '.mat'];
if exist(datafile, 'file')
    sessionData = load(datafile);
    sessionData.time = [sessionData.time; now Inf];
else
    sessionData = struct(...
        'sessionName', sessionName, ...
        'time', [now Inf], ...
        'events', zeros(10000, 2), ...
        'nEvents', 0, ...
        'CONFIG', rmfield(CONFIG, {'daq', 'osd', 'eyeTracker'}) ...
    );
end

state = STATE_CALIBRATE;
nextState = STATE_CALIBRATE;
pointRadius = round(PMAngleToPixels(CONFIG.fixationPointRadius));

dbstop if error;

%% Main loop
while state
    if state == STATE_CALIBRATE
        timestamp = GetSecs();
        
        CONFIG.eyeTracker.calibrate();
        nextState = STATE_MANUAL;
    elseif state == STATE_MANUAL
        CONFIG.osd.keyInfo = struct(...
            'LEFT', 'Left dot',...
            'RIGHT', 'Right dot',...
            'C', 'Center',...
            'UP', 'Top dot',...
            'DOWN', 'Bottom dot',...
            'M', 'Automatic control',...
            'J', 'Give juice',...
            'ESC', 'Quit'...
        );
        CONFIG.osd.state = 'Manual Control';
        CONFIG.osd.redraw();
        
        whatHappened = 0;
        output = false;
        dot = [0 0];
        
        while whatHappened ~= 1 || (output ~= KEY_MODE && output ~= KEY_QUIT)
            pointCenter = CONFIG.displayCenter+round(PMAngleToPixels(dot));
            PMScreen('FillOval', CONFIG.mainDisplayPtr, 255, ...
                [pointCenter-pointRadius pointCenter+pointRadius]);
            timestamp = PMScreen('Flip', CONFIG.mainDisplayPtr);
            CONFIG.eyeTracker.clearTargets();
            CONFIG.eyeTracker.plotTarget(dot, CONFIG.fixationRadius);

            % Wait for fixation, motion, or keypress
            [whatHappened, output] = PMSelect( ...
               PMEvKeyPress([KEY_CENTER KEY_LEFT KEY_RIGHT KEY_UP KEY_DOWN ...
                KEY_JUICE KEY_MODE KEY_QUIT], true), ... 
               PMEvMotion() ...
            );
            
            if whatHappened == 1        % Key press
                if output == KEY_CENTER
                    dot = [0 0];
                elseif output == KEY_LEFT
                    dot = [-CONFIG.dotEccentricity 0];
                elseif output == KEY_RIGHT
                    dot = [CONFIG.dotEccentricity 0];
                elseif output == KEY_UP
                    dot = [0 -CONFIG.dotEccentricity];
                elseif output == KEY_DOWN
                    dot = [0 CONFIG.dotEccentricity];
                elseif output == KEY_JUICE
                    CONFIG.daq.giveJuice(CONFIG.juiceManual);
                elseif output == KEY_MODE
                    nextState = STATE_AUTO;
                elseif output == KEY_QUIT
                    nextState = STATE_END;
                end
            end
        end
    elseif state == STATE_AUTO
        CONFIG.osd.keyInfo = struct(...
            'H', 'Horizontal only',...
            'V', 'Vertical only',...
            'A', 'All',...
            'M', 'Manual control',...
            'J', 'Give juice',...
            'ESC', 'Quit'...
        );
        CONFIG.osd.state = 'Automatic Control';
        CONFIG.osd.redraw();
        
        % Wait for fixation, motion, or keypress
        output = false;
        horizontalDots = [-CONFIG.dotEccentricity 0
            0 0
            CONFIG.dotEccentricity 0
            0 0];
        verticalDots = [0 -CONFIG.dotEccentricity
            0 0
            0 CONFIG.dotEccentricity
            0 0];
        dots = [horizontalDots; verticalDots];
        dotIndex = 1;
        
        while output ~= KEY_MODE && output ~= KEY_QUIT
            dot = dots(dotIndex, :);
            
            pointCenter = CONFIG.displayCenter+round(PMAngleToPixels(dot));
            PMScreen('FillOval', CONFIG.mainDisplayPtr, 255, ...
                [pointCenter-pointRadius pointCenter+pointRadius]);
            timestamp = PMScreen('Flip', CONFIG.mainDisplayPtr);
            CONFIG.eyeTracker.clearTargets();
            CONFIG.eyeTracker.plotTarget(dot, CONFIG.fixationRadius);
            advanceTime = timestamp + CONFIG.dotTime;
            
            while true
                curTime = GetSecs();
                rewardTime = curTime + CONFIG.dotRewardTime;
                advanceIfTimedOut = rewardTime > advanceTime;
                if advanceIfTimedOut
                	timeUntil = advanceTime;
                else
                    timeUntil = rewardTime;
                end
                
                % Wait for fixation, motion, or keypress
                [whatHappened, output] = PMSelect( ...
                   PMEvKeyPress([KEY_HORIZONTAL KEY_VERTICAL KEY_ALL ...
                    KEY_JUICE KEY_QUIT], true), ... 
                   PMEvTimer(timeUntil), ...
                   PMEvFixate(dot, CONFIG.fixationRadius, true), ...
                   PMEvMotion() ...
                );

                if whatHappened == 1        % Key press
                    if output == KEY_HORIZONTAL
                        dots = horizontalDots;
                        dotIndex = 1;
                        break;
                    elseif output == KEY_VERTICAL
                        dots = verticalDots;
                        dotIndex = 1;
                        break;
                    elseif output == KEY_CENTER
                        dots = [0 0];
                        dotIndex = 1;
                        break;
                    elseif output == KEY_ALL
                        dots = [horizontalDots; verticalDots];
                        dotIndex = 1;
                        break;
                    elseif output == KEY_JUICE
                        CONFIG.daq.giveJuice(CONFIG.juiceManual);
                    elseif output == KEY_MODE
                        nextState = STATE_MANUAL;
                        break;
                    elseif output == KEY_QUIT
                        nextState = STATE_END;
                        break;
                    end
                elseif whatHappened == 2    % Timer activated
                    if advanceIfTimedOut
                        dotIndex = dotIndex + 1;
                        if dotIndex > size(dots, 1)
                            dotIndex = 1;
                        end
                        break;
                    else
                        CONFIG.daq.giveJuice(CONFIG.juiceTimeCorrect, ...
                            CONFIG.juiceBetweenCorrect, CONFIG.juiceRepsCorrect);
                    end
                end
            end
        end
    end
    
    % Save events
    sessionData.nEvents = sessionData.nEvents + 1;
    if(sessionData.nEvents > size(sessionData.events, 1))
        sessionData.events = [sessionData.events; zeros(10000, 2)];
    end
    sessionData.events(sessionData.nEvents, :) = [state timestamp];
    
    % Continue to next state
    state = nextState;
end

% Close windows and reset DAQ
daqreset;
PMScreen('CloseAll');

% Save data
sessionData.events = sessionData.events(1:sessionData.nEvents, :);
sessionData.time(end, 2) = now;
save(datafile, '-struct', 'sessionData');

end
