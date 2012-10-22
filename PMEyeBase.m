classdef PMEyeBase < handle
% PMEYEBASE  Base eye tracker
%   PMEYEBASE is the base eye tracker from which all others must inherit.
    properties(SetAccess = protected, GetAccess = public)
        config = struct();
        PM;
    end
    
    properties(Constant)
        FIXATION_POINT_RADIUS = 0.2;
    end
    
    methods(Abstract)
        init(self)
        % INIT Initialize eye tracker 
        %   TRACKER.INIT() is called after PsychoMonkey is initialized to
        %   complete setup.
        
        getEyePosition(self, retrieveSamples)
        % GETEYEPOSITION Gets eye position and updates OSD
        %   EYEPOSITION = TRACKER.GETEYEPOSITION() gets the current eye 
        %   position in pixels and updates the auxiliary display
        
        calibrate(self)
        % CALIBRATE Calibrate the eye tracker
        %   SUCCESS = TRACKER.CALIBRATE() shows the dot pattern to calibrate
        %   the eye tracker. If SUCCESS is false, the user cancelled
        %   calibration.
        
        correctDrift(self, correctX, correctY, numberOfSamples)
        % CORRECTDRIFT Corrects drift using known pupil position.
        %   TRACKER.CORRECTDRIFT(CORRECTX, CORRECTY) assumes that the subject
        %   is fixating on an object at pixel coordinates
        %   (CORRECTX, CORRECTY) and corrects the eye signal to compensate
        %   using the median of the previous 50 samples of eye data.
        %   TRACKER.CORRECTDRIFT(CORRECTX, CORRECTY, NUMBEROFSAMPLES) specifies
        %   the median of the previous NUMBEROFSAMPLES samples should be
        %   used to compute the offset.
    end
    
    methods
        function f = fFixate(self, location, radius, invert)
        %FFIXATE Create a fixation function
        %   FFIXATE(LOCATION) creates a function that returns true
        %   when the subject fixates within the rect defined by LOCATION, 
        %   specified in pixels
        %
        %   FFIXATE(LOCATION, RADIUS) creates a function that returns true
        %   when the subject fixates within RADIUS pixels of LOCATION
        %
        %   FFIXATE(LOCATION, ..., true) creates a function that returns
        %   true when the subject's fixation leaves the specified interval
            if ~exist('invert', 'var')
                invert = false;
            end

            function isFinished = innerFunctionCircle()
                dist = norm(location-self.getEyePosition());
                fixated = find(dist < radius, 1);
                if invert
                    isFinished = isempty(fixated);
                elseif ~isempty(fixated);
                    isFinished = fixated;
                else
                    isFinished = false;
                end
            end
            function isFinished = innerFunctionRectangle()
                eyeLocation = self.getEyePosition();
                fixated = find(eyeLocation(1) >= location(:, 1) ...
                    & eyeLocation(1) <= location(:, 3) & eyeLocation(2) >= location(:, 2) ...
                    & eyeLocation(2) <= location(:, 4), 1);
                if invert
                    isFinished = isempty(fixated);
                elseif ~isempty(fixated);
                    isFinished = fixated;
                else
                    isFinished = false;
                end
            end

            if exist('radius', 'var') && ~isempty(radius)
                if size(location, 2) ~= 2
                    error('FFIXATE(LOCATION, RADIUS) requires that LOCATION be specified as a point or a n x 2 matrix');
                end
                if length(radius) ~= 1 && length(radius) ~= size(location, 2)
                    error('FFIXATE(LOCATION, RADIUS) requires that RADIUS be specified a single number or the same size as LOCATION');
                end
                f = @innerFunctionCircle;
            else
                if length(location) ~= 4
                    error('FFIXATE(LOCATION) requires a 4-element rect or an n x 4 matrix');
                end
                f = @innerFunctionRectangle;
            end
        end
        
        function fn = fAnimatePoint(self, pointCenter)
        %FANIMATEPOINT Animates a point at the specified location
        %   TRACKER.FANIMATEPOINT() returns a function that steps through an
        %   animation at the specified location, using synchronous flips.
        %   It returns TRUE when the animation is complete.
            PM = self.PM; %#ok<*PROP>
            radii = round(PM.angleToPixels(self.FIXATION_POINT_RADIUS));
            radii = [repmat(radii:radii/2:radii*5, 1, 4) radii];
            index = 1;
            
            function isFinished = animationFunction()
                % Check if finished
                isFinished = index > length(radii);
                if isFinished
                    return;
                end
                
                % Show oval
                PM.screen('FillOval', 255, ...
                    [pointCenter-radii(index) pointCenter+radii(index)]);
                index = index + 1;
                PM.screen('Flip');
            end
            
            fn = @animationFunction;
        end
        
        function fn = fBlinkPoint(self, pointCenter)
        %FBLINKPOINT Blinks a point at the specified location
        %   TRACKER.FBLINKPOINT() returns a function that blinks a point on
        %   and off at the specified location. It returns TRUE when the
        %   animation is complete.
            PM = self.PM;
            radius = round(PM.angleToPixels(self.FIXATION_POINT_RADIUS));
            rect = [pointCenter-radius pointCenter+radius];
            showingPoint = false;
            blinksRemaining = 6;
            secsBetween = 50e-3;
            timer = 0;
            
            function isFinished = animationFunction()
                % Check if finished
                isFinished = blinksRemaining == 0;
                if isFinished
                    return;
                end
                
                if GetSecs() > timer
                    if ~showingPoint
                        % Show oval
                        PM.screen('FillOval', 255, rect);
                        blinksRemaining = blinksRemaining - 1;
                    end
                    flipTime = PM.screen('Flip');
                    showingPoint = ~showingPoint;
                    timer = flipTime + secsBetween;
                end
            end
            
            fn = @animationFunction;
        end
    end
end
