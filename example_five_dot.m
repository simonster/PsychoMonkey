function example_five_dot(config)
%% Define states and keycodes
STATE_END = 0;
STATE_MANUAL = 2;
STATE_AUTO = 3;

%% Initialization
PM = PsychoMonkey(config.PM_config);
PMDAQ(PM, config.PMDAQ_config);
%PMEyeLink(PM, config.PMEyeLink_config);
PMEyeSim(PM, [-7 0; 7 0; 0 -7; 0 7; 0 0]);
PMServer(PM, config.PMServer_config);
PM.init();

% Initialize performance info for OSD
trialInfo = struct(...
    'Success', [0 0] ...
);
PM.setTrialInfo(trialInfo);

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
        'config', config ...
    );
end

%% Set initial constants and begin main loop
state = STATE_MANUAL;
nextState = state;
dotRadius = round(PM.angleToPixels(config.fixationPointRadius));
fixationRadius = PM.angleToPixels(config.fixationRadius);

dbstop if error;
PM.EyeTracker.calibrate();
while state
    if state == STATE_MANUAL
        %% Manual control
        PM.setState('Manual Control');
        
        dotAngle = [0 0];
        
        keys = struct(...
            'C', 'Calibrate',...
            'LEFTARROW', 'Left dot',...
            'RIGHTARROW', 'Right dot',...
            'E', 'Center',...
            'UPARROW', 'Top dot',...
            'DOWNARROW', 'Bottom dot',...
            'M', 'Automatic control',...
            'J', 'Give juice',...
            'ESCAPE', 'Quit'...
        );
        
        while nextState == STATE_MANUAL
            dotCenter = PM.displayCenter+PM.angleToPixels(dotAngle);
            
            PM.screen('FillOval', 255, ...
                [dotCenter-dotRadius dotCenter+dotRadius]);
            timestamp = PM.screen('Flip');
            PM.clearTargets();
            PM.plotTarget(dotCenter, fixationRadius);

            % Wait for keypress
            [~, key] = PM.select(PM.fKeyPress(keys, true));
            
            switch key
                case 'C'
                    PM.EyeTracker.calibrate();
                case 'LEFTARROW'
                    dotAngle = [-config.dotEccentricity 0];
                case 'RIGHTARROW'
                    dotAngle = [config.dotEccentricity 0];
                case 'E'
                    dotAngle = [0 0];
                case 'UPARROW'
                    dotAngle = [0 -config.dotEccentricity];
                case 'DOWNARROW'
                    dotAngle = [0 config.dotEccentricity];
                case 'J'
                    PM.DAQ.giveJuice(config.juiceManual);
                case 'M'
                    nextState = STATE_AUTO;
                case 'ESCAPE'
                    nextState = STATE_END;
            end
        end
    elseif state == STATE_AUTO
        %% Automatic control
        PM.setState('Automatic Control');
        
        horizontalDots = [-config.dotEccentricity 0
            0 0
            config.dotEccentricity 0
            0 0];
        verticalDots = [0 -config.dotEccentricity
            0 0
            0 config.dotEccentricity
            0 0];
        dots = [horizontalDots; verticalDots];
        dotIndex = 1;
        
        keys = struct(...
            'C', 'Calibrate',...
            'E', 'Center only',...
            'H', 'Horizontal only',...
            'V', 'Vertical only',...
            'A', 'All',...
            'M', 'Manual control',...
            'J', 'Give juice',...
            'ESCAPE', 'Quit'...
        );
        
        while nextState == STATE_AUTO
            dotAngle = dots(dotIndex, :);
            dotCenter = PM.displayCenter+PM.angleToPixels(dotAngle);
            
            PM.screen('FillOval', 255, ...
                [dotCenter-dotRadius dotCenter+dotRadius]);
            timestamp = PM.screen('Flip');
            PM.clearTargets();
            PM.plotTarget(dotCenter, fixationRadius);
            advanceTime = timestamp + config.dotTime;
            
            while true
                curTime = GetSecs();
                rewardTime = curTime + config.dotRewardTime;
                advanceIfTimedOut = rewardTime > advanceTime;
                if advanceIfTimedOut
                	timeUntil = advanceTime;
                else
                    timeUntil = rewardTime;
                end
                
                % Wait for fixation, motion, or keypress
                [whatHappened, key] = PM.select( ...
                   PM.fKeyPress(keys, true), ... 
                   PM.fTimer(timeUntil), ...
                   PM.EyeTracker.fFixate(dotCenter, fixationRadius, true) ...
                );

                if whatHappened == 1        % Key press
                    switch key
                        case 'C'
                            PM.EyeTracker.calibrate();
                        case 'E'
                            dots = [0 0];
                            dotIndex = 1;
                            break;
                        case 'H'
                            dots = horizontalDots;
                            dotIndex = 1;
                            break;
                        case 'V'
                            dots = verticalDots;
                            dotIndex = 1;
                            break;
                        case 'A'
                            dots = [horizontalDots; verticalDots];
                            dotIndex = 1;
                            break;
                        case 'J'
                            PM.DAQ.giveJuice(config.juiceManual);
                        case 'M'
                            nextState = STATE_MANUAL;
                            break;
                        case 'ESCAPE'
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
                        PM.DAQ.giveJuice(config.juiceTimeCorrect, ...
                            config.juiceBetweenCorrect, config.juiceRepsCorrect);
                    end
                end
            end
        end
    end
    
    %% Save events
    sessionData.nEvents = sessionData.nEvents + 1;
    if(sessionData.nEvents > size(sessionData.events, 1))
        sessionData.events = [sessionData.events; zeros(10000, 2)];
    end
    sessionData.events(sessionData.nEvents, :) = [state timestamp];
    
    state = nextState;
end

%% Cleanup
% Save data
sessionData.events = sessionData.events(1:sessionData.nEvents, :);
sessionData.time(end, 2) = now;
save(datafile, '-struct', 'sessionData');
