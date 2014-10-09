function config = example_change_detection_config()
config = struct();

%% PsychoMonkey configuration
config.PM_config = struct();

% # of the main (task) display
config.PM_config.mainDisplay = 2;

% # of the auxiliary (info) display
config.PM_config.auxDisplay = [];

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
config.fixationPointRadius = 0.3;

% Radius around the fixation dot for fixation, in degrees
config.fixationRadius = 2;

minEccentricity = 2;
maxEccentricity = 12;
nsteps = 10;
v = linspace(0, maxEccentricity, nsteps);
[x, y] = meshgrid(v, v);
xy2 = x.^2+y.^2;
[row, col] = find(xy2 >= minEccentricity^2-eps() & xy2 <= maxEccentricity^2+eps());
config.stimX = v(row);
config.stimY = v(col);
config.stimRadius = ones(1, numel(config.stimX))*0.5;

% Type of object to present (line, dot, many_lines, or many_dots)
config.object = 'many_dots';

% Half the number of features at the widest point
config.nFeatureRadius = 3;

% Spacing between features, in units of features
config.featureSpacing = 1;

% Juice given manually (seconds)
config.juiceTimeManual = 50e-3;

% Minimum duration of juice pulses for a correct response
config.juiceTimeCorrectMin = 75e-3;

% Maximum duration of juice pulses for a correct response
config.juiceTimeCorrectMax = 75e-3;

% Number of steps between minimum and maximum juice time
config.juiceTimeSteps = 5;

% Amount of time between juice pulses for correct response
config.juiceBetweenCorrect = 100e-3;

% Number of juice pulses given for correct response
config.juiceRepsCorrect = 2;

% How long the animal must fixate before stimuli appear
config.initialFixationTime = 0e-3;

% How long to show stimulus
config.stimulusTime = 96e-3;

% How long to show blank
config.blankTime = 96e-3;

% How much continuous fixation before reward
config.rewardTime = 1000e-3;

% Time between trials
config.interTrialInterval = 0e-3;

% Time penalty for losing fixation
config.timeoutFixationLost = 0e-3;

% Time penalty if initial fixation is lost
config.timeoutInitialFixationLost = 0;
