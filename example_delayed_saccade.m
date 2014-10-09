function example_change_detection(config)
%% Initialization
PM = PsychoMonkey(config.PM_config);
PMDAQ(PM, config.PMDAQ_config);
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
    sessionName = ['Session ' datestr(now, 'yyyy-mm-dd HHMMSS')];
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
        'nEvents', 0, ...
        'config', config ...
    );
    events = cell(0, 2);
    trials = [];
end

%% Set initial constants and begin main loop
interTrialInterval = 0;

%% Closures
function event(state, timestamp, updateState)
%EVENT  Save an event, optionally updating the current state
    if ~exist('timestamp', 'var')
        timestamp = GetSecs();
    end
    events(end+1, :) = {state timestamp};
    if exist('updateState', 'var') && updateState
        PM.setState(state);
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
            PM.select(PM.EyeTracker.fAnimatePoint(PM.displayCenter), keyboardFn);
            error('paradigm:continue', 'Restart loop');
        case 'J'
            PM.DAQ.giveJuice(config.juiceTimeManual, 0, 1);
        case 'D'
            PM.EyeTracker.correctDrift(PM.displayCenter(1), PM.displayCenter(2));
        case 'C'
            event('Calibrate');
            PM.EyeTracker.calibrate();
            error('paradigm:continue', 'Restart loop');
        case 'ESCAPE'
            error('paradigm:exit', 'User exited');
    end
end

dbstop if error;
PM.EyeTracker.calibrate();
dotRadius = round(PM.angleToPixels(config.fixationPointRadius));
fixationRadius = PM.angleToPixels(config.fixationRadius);
fixationColor = 255;

squareSizePixels = round(PM.angleToPixels(config.squareSize));
targetRadiusPixels = round(PM.angleToPixels(config.targetRadius));
squareLocationsPixels = round(PM.angleToPixels(config.squareLocations))+repmat(PM.displayCenter', 1, size(config.squareLocations, 2));

% Main loop

i = 0;
consecutiveCorrect = 0;
wmLoad = [];
trial = [];
while true
    try
        %% Inter-trial interval
        PM.clearTargets();

        % Show blank screen
        timestamp = PM.screen('Flip');

        % Set up trial variables
        if isempty(trial) || consecutiveCorrect > 0 || ~config.immediateRetry
            trial = struct(...
                'location', randi(length(config.squareLocations)) ...s
            );
        end

        if isempty(trials)
            trials = trial;
        else
            trials(end+1) = trial;
        end

        % Wait for ITI to elapse
        PM.select(PM.fTimer(timestamp+interTrialInterval), ...
            @handleKeyboard);
        interTrialInterval = config.interTrialInterval;

        %% Initial fixation
        % Show fixation dot
        event('Running Trial', timestamp, true);
        PM.screen('DrawDots', PM.displayCenter, dotRadius, fixationColor, [], 1);
        PM.plotTarget(PM.displayCenter, fixationRadius);
        timestamp = PM.screen('Flip');
        event('Fixation Point Shown', timestamp);

        % Wait for monkey to fixate
        PM.select( ...
            PM.EyeTracker.fFixate(PM.displayCenter, fixationRadius), ... 
            @handleKeyboard ...
        );

        event('Fixated', GetSecs());

        % Make sure monkey doesn't break fixation
        whatHappened = PM.select( ...
           PM.EyeTracker.fFixate(PM.displayCenter, fixationRadius, true), ... 
           PM.fTimer(GetSecs()+config.initialFixationTime), ...
           @handleKeyboard ...
        );

        if whatHappened == 1
            event('Initial Fixation Lost', GetSecs(), true);
            %consecutiveCorrect = 0;
            interTrialInterval = config.timeoutInitialFixationLost;
            continue;
        end

        %% Sample display
        PM.screen('DrawDots', PM.displayCenter, dotRadius, fixationColor, [], 1);
        PM.screen('DrawDots', squareLocationsPixels(:, trial.location), squareSizePixels,...
            config.sampleColor, [], config.squareType);
        timestamp = PM.screen('Flip');
        event('Sample', timestamp);

        whatHappened = PM.select( ...
            PM.EyeTracker.fFixate(PM.displayCenter, fixationRadius, true), ... 
            PM.fTimer(GetSecs()+config.sampleTime), ...
            @handleKeyboard ...
        );

        if whatHappened == 1
            event('Fixation Lost', GetSecs(), true);
            PM.incrementTrialInfo(trialInfoKeys, [false true]);
            consecutiveCorrect = 0;
            interTrialInterval = interTrialInterval + config.timeoutFixationLost;
            continue;
        end

        %% Delay period
        if config.delayTime
            PM.screen('DrawDots', PM.displayCenter, dotRadius, fixationColor, [], 1);
            timestamp = PM.screen('Flip');
            event('Delay Period', timestamp);

            whatHappened = PM.select( ...
                PM.EyeTracker.fFixate(PM.displayCenter, fixationRadius, true), ... 
                PM.fTimer(GetSecs()+config.delayTime), ...
                @handleKeyboard ...
            );

            if whatHappened == 1
                event('Fixation Lost', GetSecs(), true);
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
        timestamp = PM.screen('Flip');
        event('Test', timestamp);

        % Wait for eye to leave region around fixation dot
        whatHappened = PM.select( ...
            PM.fTimer(GetSecs()+config.maxReactionTime), ...
            PM.EyeTracker.fFixate(PM.displayCenter, fixationRadius, true), ... 
            @handleKeyboard ...
        );

        if whatHappened == 1
            event('Fixation Lost', GetSecs(), true);
            PM.incrementTrialInfo(trialInfoKeys, [false true]);
            consecutiveCorrect = 0;
            interTrialInterval = interTrialInterval + config.timeoutFixationLost;
            continue;
        end

        % Wait for eye to reach the square
        [whatHappened] = PM.select( ...
            PM.fTimer(GetSecs()+config.maxSaccadeTime), ...
            fSquare, ...
            @handleKeyboard ...
        );

        if whatHappened == 1
            event('Incorrect', GetSecs(), true);
            PM.incrementTrialInfo(trialInfoKeys, [false false]);
            consecutiveCorrect = 0;
            interTrialInterval = interTrialInterval + config.timeoutFixationLost;
        else
            event('Correct Trial', GetSecs(), true);
            PM.incrementTrialInfo(trialInfoKeys, [true false]);
            juiceTime = config.juiceTimeCorrectMin+(config.juiceTimeCorrectMax-config.juiceTimeCorrectMin)/config.juiceTimeSteps*min(config.juiceTimeSteps, consecutiveCorrect);
            consecutiveCorrect = consecutiveCorrect + 1;
            PM.DAQ.giveJuice(juiceTime, ...
                config.juiceBetweenCorrect, config.juiceRepsCorrect);
        end
    catch e
        if strcmp(e.identifier, 'paradigm:continue')
            interTrialInterval = 0;
        else
            %% Cleanup
            % Save data
            sessionData.events = events;
            sessionData.time(end, 2) = now;
            sessionData.trials = trials;
            save(datafile, '-struct', 'sessionData');
            
            if strcmp(e.identifier, 'paradigm:exit')
                break
            else
                rethrow(e);
            end
        end
    end
end
end
