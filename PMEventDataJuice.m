classdef PMEventDataJuice < event.EventData
% PMEVENTDATAJUICE  EventData object for PMDAQ juice event
    properties
        time;
        between;
        reps;
    end
    
    methods
        function self = PMEventDataJuice(time, between, reps)
            self.time = time;
            self.between = between;
            self.reps = reps;
        end
    end
end
