classdef LightCrafter4500 < handle

    properties (SetAccess = private)
        refreshRate
        LEDS
        LEDS_EACH
    end

    properties (Constant)
        NATIVE_RESOLUTION = [912, 1140];
        MIN_PATTERN_BIT_DEPTH = 1
        MAX_PATTERN_BIT_DEPTH = 8
    end

    properties (Constant, Access = private)
        LEDS_standard = {'none', 'red', 'green', 'red+green', 'blue', 'blue+red', 'blue+green', 'white'}
        LEDS_uv = {'none', 'green', 'uv', 'green+uv', 'blue', 'blue+green', 'blue+uv', 'blue+uv+green'};
        LEDS_uv2 = {'none', 'blue', 'uv', 'blue+uv', 'green', 'green+blue', 'green+uv', 'green+uv+blue'};
        LEDS_EACH_standard = {'red','green','blue'};
        LEDS_EACH_uv = {'green','uv','blue'};
        LEDS_EACH_uv2 = {'blue','uv','green'};
        
        MIN_EXPOSURE_PERIODS = [235, 700, 1570, 1700, 2000, 2500, 4500, 8333] % increasing bit depth order, us
        NUM_BIT_PLANES = 24
    end

    methods

        function obj = LightCrafter4500(refreshRate, colorMode)
            obj.refreshRate = refreshRate;
            if nargin < 2
                colorMode = 'standard';
            end
            if strcmp(colorMode, 'uv')
                obj.LEDS = obj.LEDS_uv;
                obj.LEDS_EACH = obj.LEDS_EACH_uv;
            elseif strcmp(colorMode, 'uv2')
                obj.LEDS = obj.LEDS_uv2;
                obj.LEDS_EACH = obj.LEDS_EACH_uv2;
            else
                obj.LEDS = obj.LEDS_standard;
                obj.LEDS_EACH = obj.LEDS_EACH_standard;
            end
        end

        function delete(obj)
            obj.disconnect();
        end

        function connect(obj) %#ok<MANU>
            nRetry = 5;
            for i = 1:nRetry
                try
                    lcrOpen();
                    break;
                catch x
                    lcrClose();
                    if i == nRetry
                        rethrow(x);
                    end
                end
            end
        end

        function disconnect(obj) %#ok<MANU>
            lcrClose();
        end

        function m = getMode(obj) %#ok<MANU>
            tf = lcrGetMode();
            if tf
                m = 'pattern';
            else
                m = 'video';
            end
        end

        function setMode(obj, mode) %#ok<INUSL>
            if strcmpi(mode, 'video')
                tf = false;
            elseif strcmpi(mode, 'pattern')
                tf = true;
            else
                error('Mode must be ''video'' or ''pattern''');
            end
            lcrSetMode(tf);
        end

        function [auto, red, green, blue] = getLedEnables(obj) %#ok<MANU>
            [auto, red, green, blue] = lcrGetLedEnables();
        end

        function setLedEnables(obj, auto, red, green, blue) %#ok<INUSL>
            lcrSetLedEnables(auto, red, green, blue);
        end

        function [red, green, blue] = getLedCurrents(obj) %#ok<MANU>
            [red, green, blue] = lcrGetLedCurrents();
            red = 255 - red;
            green = 255 - green;
            blue = 255 - blue;
        end

        function setLedCurrents(obj, red, green, blue) %#ok<INUSL>
            if red < 0 || red > 255 || green < 0 || green > 255 || blue < 0 || blue > 255
                error('Current must be between 0 and 255');
            end

            lcrSetLedCurrents(255 - red, 255 - green, 255 - blue);
        end

        function setImageOrientation(obj, northSouthFlipped, eastWestFlipped) %#ok<INUSL>
            lcrSetShortAxisImageFlip(northSouthFlipped);
            lcrSetLongAxisImageFlip(eastWestFlipped);
        end

        function r = currentPatternRate(obj)
            [~, ~, numPatterns] = obj.getPatternAttributes();
            r = numPatterns * obj.refreshRate;
        end

        function n = maxNumPatternsForBitDepth(obj, bitDepth)
            n = floor(min(obj.NUM_BIT_PLANES / bitDepth, 1/obj.refreshRate/(obj.MIN_EXPOSURE_PERIODS(bitDepth) * 1e-6)));
        end

        function setPatternAttributes(obj, bitDepth, color, numPatterns)
            if ~isa(color, 'cell')
                color = {color, 'none', 'none'};
            end
            
            maxNumPatterns = obj.maxNumPatternsForBitDepth(bitDepth);

            if nargin < 4 || isempty(numPatterns)
                numPatterns = maxNumPatterns;
            end

            if numPatterns > maxNumPatterns
                error(['The number of patterns must be less than or equal to ' num2str(maxNumPatterns)]);
            end

            if ~strcmpi(obj.getMode(), 'pattern')
                error('Must be in pattern mode to set pattern attributes');
            end

            if bitDepth < obj.MIN_PATTERN_BIT_DEPTH || bitDepth > obj.MAX_PATTERN_BIT_DEPTH
                error(['Bit depth must be between ' num2str(obj.MIN_PATTERN_BIT_DEPTH) ' and ' num2str(obj.MAX_PATTERN_BIT_DEPTH)]);
            end

            % Stop the current pattern sequence.
            lcrPatternDisplay(0);

            % Clear locally stored pattern LUT.
            lcrClearPatLut();

            % Create new pattern LUT.
            for i = 1:numPatterns
                if i == 1
                    trigType = 1; % external positive
                    bufSwap = true;
                else
                    trigType = 3; % no trigger
                    bufSwap = false;
                end

                patNum = i - 1;
                invertPat = false;
                insertBlack = false;
                trigOutPrev = false;
                
                colorIndex = cellfun(@(c)strcmp(c, color{i}), obj.LEDS);
                ledSelect = find(colorIndex, 1, 'first') - 1;
                
                lcrAddToPatLut(trigType, patNum, bitDepth, ledSelect, invertPat, insertBlack, bufSwap, trigOutPrev);
            end

            % Set pattern display data to stream through 24-bit RGB external interface.
            lcrSetPatternDisplayMode(true);

            % Set the sequence to repeat.
            lcrSetPatternConfig(numPatterns, true, numPatterns, 0);

            % Calculate and set the necessary pattern exposure period.
            vsyncPeriod = 1 / obj.refreshRate * 1e6; % us
            exposurePeriod = vsyncPeriod / numPatterns;
            lcrSetExposureFramePeriod(exposurePeriod, exposurePeriod);

            % Set the pattern sequence to trigger on vsync.
            lcrSetPatternTriggerMode(false);

            % Send pattern LUT to device.
            lcrSendPatLut();

            % Validate the pattern LUT.
            status = lcrValidatePatLutData();
            if status == 1 || status == 3
                error('Error validating pattern sequence');
            end

            % Start the pattern sequence.
            pause(0.02);
            lcrPatternDisplay(2);
        end

        function [firstBitDepth, color, numPatterns] = getPatternAttributes(obj)
            if ~strcmpi(obj.getMode(), 'pattern')
                error('Must be in pattern mode to get pattern attributes');
            end

            % Check all patterns for a consistent bit depth (removed: and color).
            % that is, art the same as the first pattern
            [~, ~, firstBitDepth, firstLedSelect] = lcrGetPatLutItem(0);
            numPatterns = lcrGetPatternConfig();
            ledSelectByPattern = firstLedSelect;
            color = {};
            for i = 1:numPatterns
                [~, ~, thisBitDepth, thisLedSelect] = lcrGetPatLutItem(i - 1);

                if thisBitDepth ~= firstBitDepth
                    error('Nonhomogeneous bit depth');
                end
                
                ledSelectByPattern(i) = thisLedSelect;
                color{i} = obj.LEDS{ledSelectByPattern+1};
            end

        end

    end

end
