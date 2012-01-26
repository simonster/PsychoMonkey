function f = PMEvTimer(waitUntil)
%PMEvTimer Create timer event
%   PMEvTimer(WAITUNTIL) creates a function that returns true when
%   GetSecs returns WAITUNTIL or greater
f = @() GetSecs() > waitUntil;