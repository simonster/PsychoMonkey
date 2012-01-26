function PMInit()
% PMInit Initialize screens and DAQ
%   PMInit() Opens PTB windows on main window and auxiliary window (if
%   specified) and initializes the DAQ
global CONFIG;

CONFIG.screenManager = PMScreenManager();
CONFIG.daq = PMDAQ();
CONFIG.osd = PMOSD();