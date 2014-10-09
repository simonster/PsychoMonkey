function config = example_change_detection_config()
config = struct();

%% PsychoMonkey configuration
config.PM_config = struct();

% # of the main (task) display
config.PM_config.mainDisplay = 2;

% # of the auxiliary (info) display
config.PM_config.auxDisplay = 1;

% Background color of the screen
config.PM_config.backgroundColor = 32;

% Width of the main display, arbitrary units
config.PM_config.displayWidth = 41;

% Distance from the animal to the main display, same units as above
config.PM_config.displayDistance = 47;

% Whether to enable debug mode. Currently, this prints statistics about
% every PM.select() call to validate real-time performance
config.PM_config.debug = false;


%% PMDAQ configuration
config.PMDAQ_config = struct();

% DAQ adaptor name
config.PMDAQ_config.daqAdaptor = 'nidaq';

% DAQ adaptor ID
%config.PMDAQ_config.daqID = 'Dev2';
config.PMDAQ_config.daqID = 'Dev1';

% Input type. I think this will always be SingleEnded, but maybe not.
%config.PMDAQ_config.daqInputType = 'SingleEnded';

% Channel configuration. This is a struct whose fields are the names of the
% channels and whose values are the channel numbers. PMEyeAnalog expects
% two eye channels to be specified here.
%config.PMDAQ_config.analogChannels = struct();

% Juice channel. This is special because it's a digital channel.
%config.PMDAQ_config.juiceChannel = 8;
config.PMDAQ_config.juiceChannel = 0;

% Analog sample rate in Hz. If using the motion detector, this should be at
% least 10000. If not, 1000 is typically a good value.
config.PMDAQ_config.analogSampleRate = 1000;


%% PMEyeLink configuration
config.PMEyeLink_config = struct();

% Juice time for reward during calibration, in ms
config.PMEyeLink_config.juiceTime = 50e-3;

% Eye (l or r)
%config.PMEyeLink_config.eye = 'r';

% Name for EDF file on eyelink
%config.PMEyeLink_config.edfName = [num2str(floor(rand()*100000)) '.edf'];

% Whether to draw gaze targets on the EyeLink. Note that the EyeLink manual
% does not recommend this if you are recording fixation data.
%config.PMEyeLink_config.drawOnTracker = false;

config.PMEyeLink_config.areaProportion = [0.4 0.4];

%% PMServer configuration
config.PMServer_config = struct();

% Login password
config.PMServer_config.password = 'goodmonkey';


%% example_change_detection configuration
% Radius of the fixation dot, in degrees
config.fixationPointRadius = 0.4;

% Radius around the fixation dot for fixation, in degrees
config.fixationRadius = 2.2;

% Locations of squares in degrees
distance = 5;
sep = 15;
angles = 0:sep:359;
config.squareLocations = [
    cosd(angles)*distance
    sind(angles)*distance
];

config.sampleColor = 255;
config.testColor = config.PM_config.backgroundColor;

% Size of squares in degrees
config.squareSize = 1;

% 0 for squares, 1 or 2 for circles
config.squareType = 2;

% Radius around target considered in window
config.targetRadius = 2;

% Juice given manually (seconds)
config.juiceTimeManual = 50e-3;

% Minimum duration of juice pulses for a correct response
%config.juiceTimeCorrectMin = 50e-3;
config.juiceTimeCorrectMin = 75e-3;

% Maximum duration of juice pulses for a correct response
%config.juiceTimeCorrectMax = 120e-3;
config.juiceTimeCorrectMax = 75e-3;

% Number of steps between minimum and maximum juice time
config.juiceTimeSteps = 5;

% Amount of time between juice pulses for correct response
config.juiceBetweenCorrect = 100e-3;

% Number of juice pulses given for correct response
config.juiceRepsCorrect = 7;

% How long the animal must fixate before the sample appears
config.initialFixationTime = 1500e-3;

% How long the animal gets to look at the sample (seconds)
config.sampleTime = 300e-3;

% Duration of the delay period
config.delayTime = 1000e-3;

% Maximum time for test period
config.maxReactionTime = 1000e-3;

% Maximum time for saccade after losing fixation during test period
config.maxSaccadeTime = 150e-3;

% Time between trials
config.interTrialInterval = 2500e-3;

% Time penalty for losing fixation
config.timeoutFixationLost = 6000e-3;

% Time penalty for saccading to the wrong target
config.timeoutIncorrect = 4000e-3;

% Time penalty if initial fixation is lost
config.timeoutInitialFixationLost = 0;

% Whether to show the same trial again when the animal gets it wrong
config.immediateRetry = false;
