classdef PMEventDataScreenCommand < event.EventData
% PMEVENTDATAJUICE  EventData object for PsychoMonkey screenCommand event
    properties
        command;
        arguments;
        textureIndex;
    end
    
    methods
        function self = PMEventDataScreenCommand(command, arguments, textureIndex)
            self.command = command;
            self.arguments = arguments;
            if exist('textureIndex', 'var')
                self.textureIndex = textureIndex;
            end
        end
    end
end
