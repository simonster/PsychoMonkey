function f = PMEvFixate(location, radius, invert)
%PMEvFixate Create a fixation event
%   PMEvFixate(LOCATION) creates a function that returns true
%   when the subject fixates within the box defined by LOCATION, specified
%   in degrees from the center of the screen
%
%   PMEvFixate(LOCATION, RADIUS) creates a function that returns true
%   when the subject fixates within RADIUS degrees of LOCATION, specified
%   in degrees from the center of the screen
%
%   PMEvFixate(LOCATION, ..., true) creates a function that returns
%   true when the subject's fixation leaves the specified interval
global CONFIG;
if ~exist('invert', 'var')
    invert = false;
end

function isFinished = innerFunctionCircle()
    dist = norm(location-CONFIG.eyeTracker.getEyePosition());
    isFinished = (invert == (dist > radius));
end
function isFinished = innerFunctionRectangle()
    eyeLocation = CONFIG.eyeTracker.getEyePosition();
    isFinished = (invert ~= (eyeLocation(1) >= location(1) ...
        && eyeLocation(1) <= location(3) && eyeLocation(2) >= location(2) ...
        && eyeLocation(2) <= location(4)));
end

if exist('radius', 'var') && ~isempty(radius)
    if length(location) ~= 2
        error('PMEvFixate(LOCATION, RADIUS) requires that LOCATION be specified as a single point');
    end
    if length(radius) ~= 1
        error('PMEvFixate(LOCATION, RADIUS) requires that RADIUS be specified a single number');
    end
    f = @innerFunctionCircle;
else
    if length(location) ~= 4
        error('PMEvFixate(LOCATION) requires a 4-element rect');
    end
    f = @innerFunctionRectangle;
end
end