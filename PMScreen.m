function varargout = PMScreen(varargin)
% PMScreen PTB-equivalent screen function
global CONFIG;
[varargout{1:nargout}] = CONFIG.screenManager.Screen(varargin{:});
end
