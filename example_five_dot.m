function example_five_dot(sessionName)
%% Define configuration options
global CONFIG PM;
example_five_dot_config;

% Set up session data information
if ~exist('sessionName', 'var')
    sessionName = ['Session ' datestr(now, 'yyyy-mm-dd HHMMSS')];
end
CONFIG.sessionName = sessionName;

%% Define states and keycodes
STATE_END = 0;
STATE_CALIBRATE = 1;
STATE_MANUAL = 2;
STATE_AUTO = 3;
STATE_BEGIN = STATE_MANUAL;

KEY_CALIBRATE = 67;
KEY_HORIZONTAL = 72;
KEY_VERTICAL = 86;
KEY_ALL = 65;
KEY_MODE = 77;
KEY_CENTER = 69;
KEY_LEFT = 37;
KEY_RIGHT = 39;
KEY_UP = 38;
KEY_DOWN = 40;
KEY_JUICE = 74;
KEY_QUIT = 27;

%% Initialization
PMInit();

% Initialize performance info for OSD
PM.osd.performance = struct(...
    'Success', [0 0] ...
);

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
        'CONFIG', CONFIG ...
    );
end

% Initialize performance info for OSD
PM.osd.performance = struct(...
    'Left', [0 0], ...
    'Right', [0 0] ...
);
PM.osd.keyInfo = struct();

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
        'CONFIG', CONFIG ...
    );
end

state = STATE_CALIBRATE;
nextState = STATE_CALIBRATE;
preCalibrateState = STATE_MANUAL;
dotRadius = round(PMAngleToPixels(CONFIG.fixationPointRadius));
fixationRadius = PMAngleToPixels(CONFIG.fixationRadius);

dbstop if error;

%% Main loop
while state
    if state == STATE_CALIBRATE
        timestamp = GetSecs();
        
        CONFIG.eyeTracker.calibrate();
        nextState = preCalibrateState;
    elseif state == STATE_MANUAL
        PM.osd.keyInfo = struct(...
            'C', 'Calibrate',...
            'LEFT', 'Left dot',...
            'RIGHT', 'Right dot',...
            'E', 'Center',...
            'UP', 'Top dot',...
            'DOWN', 'Bottom dot',...
            'M', 'Automatic control',...
            'J', 'Give juice',...
            'ESC', 'Quit'...
        );
        PM.osd.state = 'Manual Control';
        
        dotAngle = [0 0];
        
        while nextState == STATE_MANUAL
            dotCenter = CONFIG.displayCenter+PMAngleToPixels(dotAngle);
            
            PMScreen('FillOval', 255, ...
                [dotCenter-dotRadius dotCenter+dotRadius]);
            timestamp = PMScreen('Flip');
            PM.osd.clearTargets();
            PM.osd.plotTarget(dotCenter, fixationRadius);

            % Wait for fixation, motion, or keypress
            [whatHappened, output] = PMSelect( ...
               PMEvKeyPress([KEY_CENTER KEY_LEFT KEY_RIGHT KEY_UP KEY_DOWN ...
                KEY_JUICE KEY_MODE KEY_QUIT KEY_CALIBRATE], true) ... 
            );
            
            if whatHappened == 1        % Key press
                if output == KEY_CALIBRATE
                    nextState = STATE_CALIBRATE;
                    preCalibrateState = STATE_MANUAL;
                elseif output == KEY_CENTER
                    dotAngle = [0 0];
                elseif output == KEY_LEFT
                    dotAngle = [-CONFIG.dotEccentricity 0];
                elseif output == KEY_RIGHT
                    dotAngle = [CONFIG.dotEccentricity 0];
                elseif output == KEY_UP
                    dotAngle = [0 -CONFIG.dotEccentricity];
                elseif output == KEY_DOWN
                    dotAngle = [0 CONFIG.dotEccentricity];
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
        PM.osd.keyInfo = struct(...
            'C', 'Calibrate',...
            'E', 'Center only',...
            'H', 'Horizontal only',...
            'V', 'Vertical only',...
            'A', 'All',...
            'M', 'Manual control',...
            'J', 'Give juice',...
            'ESC', 'Quit'...
        );
        PM.osd.state = 'Automatic Control';
        
        % Wait for fixation, motion, or keypress
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
        
        while nextState == STATE_AUTO
            dotAngle = dots(dotIndex, :);
            dotCenter = CONFIG.displayCenter+PMAngleToPixels(dotAngle);
            
            PMScreen('FillOval', 255, ...
                [dotCenter-dotRadius dotCenter+dotRadius]);
            timestamp = PMScreen('Flip');
            PM.osd.clearTargets();
            PM.osd.plotTarget(dotCenter, fixationRadius);
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
                   PMEvKeyPress([KEY_CENTER KEY_HORIZONTAL KEY_VERTICAL ...
                    KEY_ALL KEY_JUICE KEY_QUIT KEY_MODE KEY_CALIBRATE], true), ... 
                   PMEvTimer(timeUntil), ...
                   PMEvFixate(dotCenter, fixationRadius, true) ...
                );

                if whatHappened == 1        % Key press
                    if output == KEY_CALIBRATE
                        nextState = STATE_CALIBRATE;
                        preCalibrateState = STATE_AUTO;
                    elseif output == KEY_HORIZONTAL
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
                        PM.daq.giveJuice(CONFIG.juiceManual);
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
                        PM.daq.giveJuice(CONFIG.juiceTimeCorrect, ...
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
