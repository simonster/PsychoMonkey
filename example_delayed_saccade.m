function example_change_detection(config)
%% Initialization
% If this is higher, there will not be corresponding event codes...
assert(size(config.squareLocations, 2) < 224);
[EVENT_CODES, EVENT_NAMES] = event_codes();

PM = PsychoMonkey(config.PM_config);
DAQ = PMDAQ(PM, config.PMDAQ_config);
PMEyeLink(PM, config.PMEyeLink_config);

%PMEyeSim(PM, [0 0; 0 0; -5 -5; -5 5]);
PMServer(PM, config.PMServer_config);
PM.init();

% Initialize trialInfo
trialInfoKeys = {'Correct', 'Fixation Lost'};
trialInfo = containers.Map(trialInfoKeys, ...
    {[0 0], [0 0]});
PM.setTrialInfo(trialInfo);

% Set up session data information
if ~exist('sessionName', 'var')
    sessionName = ['Delayed Saccade ' datestr(now, 'yyyy-mm-dd HHMMSS')];
end

datafile = [sessionName '.mat'];
if exist(datafile, 'file')
    sessionData = load(datafile);
    sessionData.time = [sessionData.time; now Inf];
    events = sessionData.events;
    trials = sessionData.trials;
else
    sessionData = struct(...
        'sessionName', sessionName, ...
        'time', [now Inf], ...
        'config', config, ...
        'eventCodes', EVENT_CODES ...
    );
    sessionData.eventNames = EVENT_NAMES;
    events = zeros(2, 0);
    trials = [];
end

%% Set initial constants and begin main loop
interTrialInterval = 0;

%% Closures
function event(code, timestamp, updateState)
%EVENT  Save an event, optionally updating the current state
    DAQ.sendEvent(code);
    Eyelink('Message', EVENT_NAMES{code});
    events(1, end+1) = code;
    events(2, end) = timestamp;
    if exist('updateState', 'var') && updateState
        PM.setState(EVENT_NAMES{code});
    end
end

KEYS = struct(...
    'A', 'Attract attention', ...
    'J', 'Give juice', ...
    'D', 'Drift correction',...
    'C', 'Calibrate',...
    'ESCAPE', 'Exit'...
);
keyboardFn = PM.fKeyPress(KEYS, true);
function isFinished = handleKeyboard()
%HANDLEKEYBOARD  Look for and handle keypresses
%   HANDLEKEYBOARD() allows a keypress to 
    isFinished = false;
    key = keyboardFn();
    switch key
        case 'A'
            event(EVENT_CODES.Attract_Attention_Start, GetSecs());
            PM.select(PM.EyeTracker.fAnimatePoint(PM.displayCenter), keyboardFn);
            event(EVENT_CODES.Attract_Attention_End, GetSecs());
            error('paradigm:continue', 'Restart loop');
        case 'J'
            event(EVENT_CODES.Manual_Juice_Start, GetSecs());
            DAQ.giveJuice(config.juiceTimeManual, 0, 1);
            event(EVENT_CODES.Manual_Juice_End, GetSecs());
        case 'D'
            event(EVENT_CODES.Drift_Correct, GetSecs());
            PM.EyeTracker.correctDrift(PM.displayCenter(1), PM.displayCenter(2));
        case 'C'
            event(EVENT_CODES.Calibration_Start, GetSecs());
            PM.EyeTracker.calibrate();
            event(EVENT_CODES.Calibration_End, GetSecs());
            error('paradigm:continue', 'Restart loop');
        case 'ESCAPE'
            error('paradigm:exit', 'User exited');
    end
end

dbstop if error;
event(EVENT_CODES.Paradigm_Start, GetSecs());
event(EVENT_CODES.Paradigm_Start, GetSecs());
event(EVENT_CODES.Paradigm_Start, GetSecs());

event(EVENT_CODES.Calibration_Start, GetSecs());
PM.EyeTracker.calibrate();
event(EVENT_CODES.Calibration_End, GetSecs());
dotRadius = round(PM.angleToPixels(config.fixationPointRadius));
fixationRadius = PM.angleToPixels(config.fixationRadius);
fixationColor = 255;
blockPositionIndices = [];

squareSizePixels = round(PM.angleToPixels(config.squareSize));
targetRadiusPixels = round(PM.angleToPixels(config.targetRadius));
squareLocationsPixels = round(PM.angleToPixels(config.squareLocations))+repmat(PM.displayCenter', 1, size(config.squareLocations, 2));
photodiodeRect = [PM.displaySize - config.photodiodeSize PM.displaySize];

% Main loop

i = 0;
consecutiveCorrect = 0;
fixBreak = false;
wmLoad = [];
trial = [];
while true
    try
        %% Inter-trial interval
        PM.clearTargets();

        % Show blank screen
        if fixBreak
            PM.screen('FillRect', [96 0 0 ]);
            fixBreak = false;
        else
            PM.screen('FillRect', PM.config.backgroundColor);
        end
        PM.screen('FillRect', 0, photodiodeRect);
        timestamp = PM.screen('Flip');

        if ~isempty(trial)
            if isempty(trials)
                trials = trial;
            else
                trials(end+1) = trial;
            end
        end

        % Set up trial variables
        if config.immediateRetry && ~isempty(trial) && consecutiveCorrect == 0
            nextTrial = trial;
        else
            if isempty(blockPositionIndices)
                blockPositionIndices = 1:size(config.squareLocations, 2);
            end
            blockPositionIndex = randi(numel(blockPositionIndices));
            locationIndex = blockPositionIndices(blockPositionIndex);
            nextTrial = struct(...
                'location', locationIndex ...
            );
        end
        trial = [];

        % Wait for ITI to elapse
        PM.select(PM.fTimer(timestamp+interTrialInterval), ...
            @handleKeyboard);
        interTrialInterval = config.interTrialInterval;

        trial = nextTrial;
        trial.trackerStartTime = Eyelink('TrackerTime');
        timestamp = GetSecs();
        trial.startTime = timestamp;
        event(EVENT_CODES.Trial_Start, timestamp, true);
        event(31+locationIndex, GetSecs());
        event(31+locationIndex, GetSecs());
        event(31+locationIndex, GetSecs());

        %% Initial fixation
        % Show fixation dot
        PM.screen('FillRect', PM.config.backgroundColor);
        PM.screen('DrawDots', PM.displayCenter, dotRadius, fixationColor, [], 1);
        PM.plotTarget(PM.displayCenter, fixationRadius);
        PM.screen('FillRect', 0, photodiodeRect);
        timestamp = PM.screen('Flip');
        event(EVENT_CODES.Fixation_Shown, timestamp);

        % Wait for monkey to fixate
        PM.select( ...
            PM.EyeTracker.fFixate(PM.displayCenter, fixationRadius), ... 
            @handleKeyboard ...
        );
        event(EVENT_CODES.Fixated, GetSecs());

        % Make sure monkey doesn't break fixation
        whatHappened = PM.select( ...
           PM.EyeTracker.fFixate(PM.displayCenter, fixationRadius, true), ... 
           PM.fTimer(GetSecs()+config.initialFixationTime), ...
           @handleKeyboard ...
        );

        if whatHappened == 1
            event(EVENT_CODES.Initial_Fixation_Lost, GetSecs(), true);
            %consecutiveCorrect = 0;
            interTrialInterval = config.timeoutInitialFixationLost;
            continue;
        end

        %% Sample display
        PM.screen('DrawDots', PM.displayCenter, dotRadius, fixationColor, [], 1);
        PM.screen('DrawDots', squareLocationsPixels(:, trial.location), squareSizePixels,...
            config.sampleColor, [], config.squareType);
        PM.screen('FillRect', 255, photodiodeRect);
        timestamp = PM.screen('Flip');
        event(EVENT_CODES.Sample_Start, timestamp);

        whatHappened = PM.select( ...
            PM.EyeTracker.fFixate(PM.displayCenter, fixationRadius, true), ... 
            PM.fTimer(GetSecs()+config.sampleTime), ...
            @handleKeyboard ...
        );

        if whatHappened == 1
            fixBreak = true;
            event(EVENT_CODES.Fixation_Lost, GetSecs(), true);
            PM.incrementTrialInfo(trialInfoKeys, [false true]);
            consecutiveCorrect = 0;
            interTrialInterval = interTrialInterval + config.timeoutFixationLost;
            continue;
        end

        %% Delay period
        if config.delayTime
            PM.screen('DrawDots', PM.displayCenter, dotRadius, fixationColor, [], 1);
            PM.screen('FillRect', 0, photodiodeRect);
            timestamp = PM.screen('Flip');
            event(EVENT_CODES.Delay_Start, timestamp);

            whatHappened = PM.select( ...
                PM.EyeTracker.fFixate(PM.displayCenter, fixationRadius, true), ... 
                PM.fTimer(GetSecs()+config.delayTime), ...
                @handleKeyboard ...
            );

            if whatHappened == 1
                fixBreak = true;
                event(EVENT_CODES.Fixation_Lost, GetSecs(), true);
                PM.incrementTrialInfo(trialInfoKeys, [false true]);
                consecutiveCorrect = 0;
                interTrialInterval = interTrialInterval + config.timeoutFixationLost;
                continue;
            end
        end

        %% Test period
        PM.screen('DrawDots', squareLocationsPixels(:, trial.location), squareSizePixels,...
            config.testColor, [], config.squareType);
        PM.clearTargets();
        
        if config.squareType == 0
            squareRect = repmat(squareLocationsPixels(:, trial.location)', 1, 2)+...
                repmat([-1 -1 1 1]*targetRadiusPixels, wmLoad, 1);
            PM.plotTarget(squareRect);
            fSquare = PM.EyeTracker.fFixate(squareRect);
        else
            squareCenter = squareLocationsPixels(:, trial.location)';
            PM.plotTarget(squareCenter, targetRadiusPixels);
            fSquare = PM.EyeTracker.fFixate(squareCenter, targetRadiusPixels);
        end
        PM.screen('FillRect', 255, photodiodeRect);
        timestamp = PM.screen('Flip');
        event(EVENT_CODES.Test_Start, timestamp);

        % Wait for eye to leave region around fixation dot
        whatHappened = PM.select( ...
            PM.fTimer(GetSecs()+config.maxReactionTime), ...
            PM.EyeTracker.fFixate(PM.displayCenter, fixationRadius, true), ... 
            @handleKeyboard ...
        );
        leftDotTime = GetSecs();

        if whatHappened == 1
            event(EVENT_CODES.Fixation_Lost, leftDotTime, true);
            PM.incrementTrialInfo(trialInfoKeys, [false true]);
            consecutiveCorrect = 0;
            interTrialInterval = interTrialInterval + config.timeoutFixationLost;
            continue;
        end
        event(EVENT_CODES.Saccade_Start, leftDotTime);

        % Wait for eye to reach the square
        [whatHappened] = PM.select( ...
            PM.fTimer(GetSecs()+config.maxSaccadeTime), ...
            fSquare, ...
            @handleKeyboard ...
        );
        reachTime = GetSecs();

        if whatHappened == 1
            event(EVENT_CODES.Incorrect, reachTime, true);
            PM.incrementTrialInfo(trialInfoKeys, [false false]);
            consecutiveCorrect = 0;
            interTrialInterval = interTrialInterval + config.timeoutFixationLost;
        else
            event(EVENT_CODES.Correct, reachTime, true);
            PM.incrementTrialInfo(trialInfoKeys, [true false]);
            juiceTime = config.juiceTimeCorrectMin+(config.juiceTimeCorrectMax-config.juiceTimeCorrectMin)/config.juiceTimeSteps*min(config.juiceTimeSteps, consecutiveCorrect);
            consecutiveCorrect = consecutiveCorrect + 1;
            blockPositionIndices(blockPositionIndex) = [];
            
            PM.screen('DrawDots', squareLocationsPixels(:, trial.location), squareSizePixels,...
                config.sampleColor, [], config.squareType);
            PM.screen('FillRect', 0, photodiodeRect);
            PM.screen('Flip');
            [whatHappened] = PM.select( ...
                PM.fTimer(GetSecs()+0.05), ...
                @handleKeyboard ...
            );
            PM.DAQ.giveJuice(juiceTime, ...
                config.juiceBetweenCorrect, config.juiceRepsCorrect);
        end
    catch e
        if strcmp(e.identifier, 'paradigm:continue')
            interTrialInterval = 0;
        else
            event(EVENT_CODES.Paradigm_End, GetSecs());
            event(EVENT_CODES.Paradigm_End, GetSecs());
            event(EVENT_CODES.Paradigm_End, GetSecs());
            PM.screen('FillRect', PM.config.backgroundColor);
            PM.screen('Flip');
            PM.screen('Flip');
            %% Cleanup
            % Save data
            sessionData.events = events;
            sessionData.time(end, 2) = now;
            sessionData.trials = trials;
            save(datafile, '-struct', 'sessionData');
            Eyelink('ReceiveFile', [], [sessionName '.edf']);
            
            if strcmp(e.identifier, 'paradigm:exit')
                break
            else
                rethrow(e);
            end
        end
    end
end
end
