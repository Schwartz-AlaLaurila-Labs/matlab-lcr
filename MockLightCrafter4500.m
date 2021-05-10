classdef MockLightCrafter4500 < LightCrafter4500
    %emulates a lightcrafter connection
        
    properties (Access=private)
        mode = true;
        led_enable = false(4,1);
        led_currents = zeros(3,1);
        
        bitDepth
        color
        numPatterns
    end
    
    methods
        function self = MockLightCrafter4500(refreshRate, colorMode)
            self@LightCrafter4500(refreshRate, colorMode);
            self.color = {self.LEDS_EACH{1}, 'none', 'none'};
            self.bitDepth = self.MAX_PATTERN_BIT_DEPTH;
            self.numPatterns = 1;
        end
        
        function connect(~)
            return
        end
        function disconnect(~)
            return
        end
        function m = getMode(self)
            if self.mode
                m = 'pattern';
            else
                m = 'video';
            end
        end

        function setMode(self, mode)
            if strcmpi(mode, 'video')
                self.mode = false;
            elseif strcmpi(mode, 'pattern')
                self.mode = true;
            else
                error('Mode must be ''video'' or ''pattern''');
            end
        end
        
        function varargout = getLedEnables(self)
            [varargout(:)] = num2cell(self.led_enable);
        end
        
        function setLedEnables(self, varargin)
            self.led_enable = cellfun(@logical, varargin);
        end
        
        function varargout = getLedCurrents(self)
            [varargout(:)] = num2cell(self.led_currents);
        end
        
        function setLedCurrents(self, varargin)
            self.led_currents = cell2mat(varargin);
        end  
        
        function setImageOrientation(~,~,~)
            return
        end
        
        function [firstBitDepth, color, numPatterns] = getPatternAttributes(self)
            if ~strcmpi(self.getMode(), 'pattern')
                error('Must be in pattern mode to get pattern attributes');
            end
            %not so sure about this one...
            firstBitDepth = self.bitDepth;
            color = self.color;
            numPatterns = self.numPatterns;        
        end
        
        function setPatternAttributes(self, bitDepth, color, numPatterns)
            if ~isa(color, 'cell')
                color = {color, 'none', 'none'};
            end
            if any(~ismember(color, self.LEDS))
                error('A selected color(s) does not exist for this projector.');
            end
            
            maxNumPatterns = self.maxNumPatternsForBitDepth(bitDepth);

            if nargin < 4 || isempty(numPatterns)
                numPatterns = maxNumPatterns;
            end

            if numPatterns > maxNumPatterns
                error(['The number of patterns must be less than or equal to ' num2str(maxNumPatterns)]);
            end

            if ~strcmpi(self.getMode(), 'pattern')
                error('Must be in pattern mode to set pattern attributes');
            end
            
            if bitDepth < self.MIN_PATTERN_BIT_DEPTH || bitDepth > self.MAX_PATTERN_BIT_DEPTH
                error(['Bit depth must be between ' num2str(self.MIN_PATTERN_BIT_DEPTH) ' and ' num2str(self.MAX_PATTERN_BIT_DEPTH)]);
            end
            
            self.color = color;
            self.bitDepth = bitDepth;
            self.numPatterns = numPatterns;
            
        end
        
        
    end
end