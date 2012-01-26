function f = PMEvMotion()
%PMEvMotion Create motion event
%   PMEvMotion(CONFIG) returns a function that returns true when the motion
%   threshold specified in CONFIG has been reached or
%   surpassed
global CONFIG;

% Clear motion data before we start
lastData = CONFIG.daq.getData('motion');
if ~isempty(lastData)
    lastData = lastData(end);
end

function isFinished = innerFunction()
    data = CONFIG.daq.getData('motion');
    if isempty(data)
        isFinished = false;
        return;
    end
    isFinished = any(abs(diff([lastData; data])) > CONFIG.motionThreshold);
    lastData = data(end);
end
f = @innerFunction;
end