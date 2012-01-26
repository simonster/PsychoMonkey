% PsychoMonkey
% Copyright (C) 2012 Simon Kornblith
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU Affero General Public License as
% published by the Free Software Foundation, either version 3 of the
% License, or (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Affero General Public License for more details.
% 
% You should have received a copy of the GNU Affero General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

classdef PMDAQ < handle
% PMDAQ DAQ abstraction interface
%   PMDAQ(AI, ADAPTOR, ID) creates a new DAQ abstraction for the specified
%   adaptor and device ID
    properties(Access = private)
        % A buffer of data that has not been requested, up to 60 seconds
        % long. Rows represent samples; columns represent channels.
        buffer;
        
        % The length of the buffer
        bufferLength;
        
        % analoginput object
        ai;
        
        % digitalio object
        dio;
        
        % Total number of channels
        nChannels;
        
        % Struct whose members indicate which channels belong to which
        % components.
        channels;
    end
    
    methods
        function self = PMDAQ()
            global CONFIG;
            daqreset;
            allChannels = [CONFIG.channelsEye CONFIG.channelsMotion];
            self.channels = struct('eye', 1:length(CONFIG.channelsEye), ...
                'motion', length(CONFIG.channelsEye)+(1:length(CONFIG.channelsMotion)));
            self.nChannels = length(allChannels);
            
            % Initialize analog IO
            self.ai = analoginput(CONFIG.daqAdaptor, CONFIG.daqID);
            addchannel(self.ai, allChannels);
            
            assert(setverify(self.ai, 'SampleRate', ...
                CONFIG.analogSampleRate) == CONFIG.analogSampleRate, ...
                'Specified sample rate not supported');
            set(self.ai, 'SamplesPerTrigger', Inf);
            if ~isempty(CONFIG.daqInputType)
                assert(strcmp(setverify(self.ai, 'InputType', ...
                    CONFIG.daqInputType), CONFIG.daqInputType), ...
                    'Specified input type not supported');
            end
            
            start(self.ai);
            
            self.buffer = zeros(CONFIG.analogSampleRate*60, self.nChannels);
            self.bufferLength = zeros(1, self.nChannels);
            
            % Initialize digital IO
            self.dio = digitalio(CONFIG.daqAdaptor, CONFIG.daqID);
            addline(self.dio, CONFIG.channelJuice, 'out');
        end
        
        function giveJuice(self, time, between, reps)
            % GIVEJUICE Administer a specified amount of juice
            %   GIVEJUICE(TIME) administers juice for TIME seconds
            %
            %   GIVEJUICE(TIME, BETWEEN, REPS) adminsters juice REPS times,
            %   with BETWEEN seconds between each administration
            if ~exist('between', 'var')
                between = 0;
            end
            if ~exist('reps', 'var')
                reps = 1;
            end
            
            for i=1:reps
                putvalue(self.dio.Line(1), 1);
                PMSelect(PMEvTimer(GetSecs()+time));
                putvalue(self.dio.Line(1), 0);
                PMSelect(PMEvTimer(GetSecs()+between));
            end
        end
        
        function data = getData(self, type)
            % GETDATA Gets all data acquired by the DAQ since last call
            %   DATA = OBJ.GETDATA('eye') gets eye position data from the
            %   daq. DATA is a n x 2 matrix, where n is the number of
            %   samples acquired since last GETDATA('eye') call.
            %   
            %   DATA = OBJ.GETDATA('motion') gets eye position data from 
            %   the DAQ. DATA is a vector of length n.
            if isfield(self.channels, type)
                channel = self.channels.(type);
                if isempty(channel)
                    error(['Attempted to get ' type ' data, but no ' ...
                        type ' channel specified']);
                end
            else
                error(['Invalid data type ' type]);
            end
            
            % Get available samples
            nSamples = get(self.ai, 'SamplesAvailable');
            if nSamples == 0
                % Short circuit for speed
                data = self.buffer(1:self.bufferLength(channel(1)), channel);
                self.bufferLength(channel) = 0;
                return;
            end
            
            % Get samples from DAQ
            data = getdata(self.ai, nSamples);
            
            % Buffer data for other channels
            otherChannels = 1:self.nChannels;
            otherChannels(channel) = [];
            maxBufferLength = size(self.buffer, 1);
            for i=otherChannels
                bufLength = self.bufferLength(i);
                if size(data, 1) > maxBufferLength
                    % If we have read more data than the buffer, clear it
                    self.buffer(:, i) = data(end-maxBufferLength+1:end, i);
                    self.bufferLength(i) = maxBufferLength;
                elseif (bufLength + nSamples) > maxBufferLength
                    % If the buffer is filled, rotate it
                    self.buffer(:, i) = [self.buffer(nSamples+1:end, i); data(:, i)];
                    self.bufferLength(i) = maxBufferLength;
                else
                    % If the buffer is not full, just add on at the end
                    self.buffer(bufLength+(1:nSamples), i) = data(:, i);
                    self.bufferLength(i) = bufLength + nSamples;
                end
            end
            
            % Return data for selected channels
            data = [self.buffer(1:self.bufferLength(channel(1)), channel); data(:, channel)];
            self.bufferLength(channel) = 0;
        end
    end
end
