function example_change_detection(config)
%% Initialization
PM = PsychoMonkey(config.PM_config);
PMDAQ(PM, config.PMDAQ_config);
PMEyeLink(PM, config.PMEyeLink_config);
% PMEyeSim(PM, [0 0; 0 0; -5 -5; -5 5]);
PMServer(PM, config.PMServer_config);
PM.init();

% Initialize trialInfo
trialInfoKeys = {'Seconds Fixated'};
trialInfo = containers.Map(trialInfoKeys, ...
    {[0 0]});
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
nextRewardTime = 0;
consecutiveCorrect = 0;
dotRadius = round(PM.angleToPixels(config.fixationPointRadius));
fixationRadius = PM.angleToPixels(config.fixationRadius);

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
    if key ~= 0
        PM.DAQ.haltJuice();
    end
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

brokeFixation = PM.EyeTracker.fFixate(PM.displayCenter, fixationRadius, true);
shouldReward = [];
function isFinished = handleGiveJuice()
    isFinished = false;
    if brokeFixation()
        consecutiveCorrect = 0;
        shouldReward = PM.fTimer(GetSecs()+config.rewardTime);
    elseif isempty(shouldReward)
        shouldReward = PM.fTimer(GetSecs()+config.rewardTime);
    elseif shouldReward()
        juiceTime = config.juiceTimeCorrectMin+(config.juiceTimeCorrectMax-config.juiceTimeCorrectMin)/config.juiceTimeSteps*min(config.juiceTimeSteps, consecutiveCorrect);
        PM.DAQ.giveJuiceAsync(juiceTime, config.juiceBetweenCorrect, config.juiceRepsCorrect);
        consecutiveCorrect = consecutiveCorrect + 1;
        shouldReward = PM.fTimer(GetSecs()+config.rewardTime);
    end
end

PM.EyeTracker.calibrate();
fixationColor = 255;


% Main loop
v = -config.nFeatureRadius:config.nFeatureRadius;
[a, b] = meshgrid(v, v);
[featureX, featureY] = find(a.^2+b.^2 <= config.nFeatureRadius^2);
featureX = v(featureX)/config.nFeatureRadius;
featureY = v(featureY)/config.nFeatureRadius;

timestamp2 = 0;
PM.plotTarget(PM.displayCenter, fixationRadius);
color = 255;
PM.screen('DrawDots', PM.displayCenter, dotRadius, fixationColor, [], 1);
while true
    try
        % Show blank
        timestamp = PM.screen('Flip');
        disp(timestamp - timestamp2);

        % Get stimulus parameters
        stimIndex = randi(numel(config.stimX));
        x = PM.displayCenter(1) + PM.angleToPixels(config.stimX(stimIndex));
        y = PM.displayCenter(2) + PM.angleToPixels(config.stimY(stimIndex));
        radius = PM.angleToPixels(config.stimRadius(stimIndex));
        featureRadius = max(1.0, radius/(2*config.nFeatureRadius*(1+config.featureSpacing)));

        % Set up dots
        dotCenters = [x + featureX*radius; y + featureY*radius];
        PM.screen('DrawDots', PM.displayCenter, dotRadius, fixationColor, [], 1);
        PM.screen('DrawDots', dotCenters, featureRadius, color, [], 1);

        % Wait for blank to end
        PM.select( ...
            PM.fTimer(timestamp+config.blankTime), ...
            @handleGiveJuice, ...
            @handleKeyboard ...
        );

        % Show features
        timestamp2 = PM.screen('Flip');
        disp(timestamp2 - timestamp);

        % Prepare fixation
        PM.screen('DrawDots', PM.displayCenter, dotRadius, fixationColor, [], 1);

        % Wait for presentation to end
        PM.select( ...
            PM.fTimer(timestamp2+config.stimulusTime), ...
            @handleGiveJuice, ...
            @handleKeyboard ...
        );
    catch e
        PM.DAQ.haltJuice();
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
                return;
            else
                rethrow(e);
            end
        end
    end
end
end
