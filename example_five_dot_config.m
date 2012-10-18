function config = example_five_dot_config()
config = struct();

%% PsychoMonkey configuration
config.PM_config = struct();

% # of the main (task) display
config.PM_config.mainDisplay = 1;

% # of the auxiliary (info) display
config.PM_config.auxDisplay = 2;

% Background color of the screen
%config.PM_config.backgroundColor = 0;

% Width of the main display, arbitrary units
config.PM_config.displayWidth = 41;

% Distance from the animal to the main display, same units as above
config.PM_config.displayDistance = 55;

% Whether to enable debug mode. Currently, this prints statistics about
% every PM.select() call to validate real-time performance
config.PM_config.debug = false;


%% PMDAQ configuration
config.PMDAQ_config = struct();

% DAQ adaptor name
config.PMDAQ_config.daqAdaptor = 'nidaq';

% DAQ adaptor ID
config.PMDAQ_config.daqID = 'Dev2';

% Input type. I think this will always be SingleEnded, but maybe not.
%config.PMDAQ_config.daqInputType = 'SingleEnded';

% Channel configuration. This is a struct whose fields are the names of the
% channels and whose values are the channel numbers. PMEyeAnalog expects
% two eye channels to be specified here.
%config.PMDAQ_config.analogChannels = struct();

% Juice channel. This is special because it's a digital channel.
config.PMDAQ_config.juiceChannel = 8;

% Analog sample rate in Hz. If using the motion detector, this should be at
% least 10000. If not, 1000 is typically a good value.
config.PMDAQ_config.analogSampleRate = 1000;


%% PMEyeLink configuration
config.PMEyeLink_config = struct();

% Juice time for reward during calibration, in ms
%config.PMEyeLink_config.juiceTime = 150e-3;

% Eye (l or r)
%config.PMEyeLink_config.eye = 'r';

% Name for EDF file on eyelink
%config.PMEyeLink_config.edfName = [num2str(floor(rand()*100000)) '.edf'];

% Whether to draw gaze targets on the EyeLink. Note that the EyeLink manual
% does not recommend this if you are recording fixation data.
%config.PMEyeLink_config.drawOnTracker = false;


%% PMServer configuration
config.PMServer_config = struct();

% Login password
config.PMServer_config.password = 'goodmonkey';


%% example_five_dot configuration
% Radius of the fixation dot, in degrees
config.fixationPointRadius = 0.2;

% Radius around the fixation dot for fixation, in degrees
config.fixationRadius = 5;

% Image width, in degrees
config.imageWidth = 4;

% Time penalty for motion (seconds)
config.timeoutMotion = 5;

% Time penalty for losing fixation
config.timeoutFixationLost = 0;

% Juice given manually (seconds)
config.juiceManual = 150e-3;

% Duration of juice pulses for a correct response
config.juiceTimeCorrect = 150e-3;

% Amount of time between juice pulses for correct response
config.juiceBetweenCorrect = 20e-3;

% Number of juice pulses given for correct response
config.juiceRepsCorrect = 2;

% Eccentricity of the dots on the screen, in degrees
config.dotEccentricity = 7;

% The amount of time the dot is on for
config.dotTime = 5000e-3;

% Reward given after fixating this long
config.dotRewardTime = 1200e-3;