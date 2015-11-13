classdef AbstractHypertoroidalDistribution
    properties
        dim       % Dimension, cart product of dim circles. dim=1 is a circle, dim=2 a torus.
    end
    
    methods (Abstract)
        % Evaluate pdf at positions stored in xa
        pdf(this, xa);
    end
    
    
    methods
        function p=plot(this, varargin)
            % Create an appropriate plot of the pdf
            %
            % Parameters:
            %   varargin
            %       parameters to be passed to plot/surf command
            % Returns:
            %   p (scalar)
            %       plot handle
            switch this.dim
                case 1
                    theta = linspace(0,2*pi,128);
                    ftheta = this.pdf(theta);
                    p = plot(theta, ftheta,varargin{:});
                case 2
                    step = 2*pi/100;
                    [alpha,beta] = meshgrid(0:step:2*pi,0:step:2*pi);
                    f = this.pdf([alpha(:)'; beta(:)']);
                    f = reshape(f,size(alpha,1), size(alpha,2));
                    p = surf(alpha, beta, f, varargin{:});
                otherwise
                    error('Plotting for this dimension is currently not supported');
            end
        end
        function m = circularMean(this)
            % Calculate the circular mean
            %
            % Returns:
            %   m (dim x 1)
            %       circular mean in [0, 2pi)^2
            a = this.trigonometricMoment(1);
            m = mod(atan2(imag(a),real(a)), 2*pi);
        end
        function m = trigonometricMoment(this, n)
            % Calculate n-th trigonometric moment, i.e., 
            % E([e^(inx_1); e^(inx_2);...^e(inx_d)])
            %
            % Parameters:
            %   n (scalar)
            %       number of moment
            % Returns:
            %   m (dx1)
            %       n-th trigonometric moment (complex vector)             
            m = trigonometricMomentNumerical(this, n);
        end
        function m = trigonometricMomentNumerical(this, n)
            % Calculate n-th trigonometric moment numerically, i.e., 
            % E([e^(inx_1); e^(inx_2);...^e(inx_d)])
            %
            % Parameters:
            %   n (scalar)
            %       number of moment
            % Returns:
            %   m (dx1)
            %       n-th trigonometric moment (complex vector)  
            switch this.dim
                case 1
                    m = integral(@(x) this.pdf(x).*exp(1i*n*x), 0, 2*pi);
                case 2
                    f1 = @(x,y) reshape(this.pdf([x(:)';y(:)']).*exp(1i*n*x(:)'), size(x));
                    f2 = @(x,y) reshape(this.pdf([x(:)';y(:)']).*exp(1i*n*y(:)'), size(x));
                    m(1,1) = integral2(f1, 0, 2*pi, 0, 2*pi);
                    m(2,1) = integral2(f2, 0, 2*pi, 0, 2*pi);
                case 3
                    f1 = @(x,y,z) reshape(this.pdf([x(:)';y(:)';z(:)']).*exp(1i*n*x(:)'), size(x));
                    f2 = @(x,y,z) reshape(this.pdf([x(:)';y(:)';z(:)']).*exp(1i*n*y(:)'), size(x));
                    f3 = @(x,y,z) reshape(this.pdf([x(:)';y(:)';z(:)']).*exp(1i*n*z(:)'), size(x));
                    m(1,1) = integral3(f1, 0, 2*pi, 0, 2*pi, 0, 2*pi);
                    m(2,1) = integral3(f2, 0, 2*pi, 0, 2*pi, 0, 2*pi);
                    m(3,1) = integral3(f3, 0, 2*pi, 0, 2*pi, 0, 2*pi);
                otherwise
                    error('Numerical moment calculation for this dimension is currently not supported');
            end
        end
        function mu = mean2dimD(this)
            % Calculates E([cos(x1), sin(x1), cos(x2), sin(x2), ...cos(xd), sin(xd)])
            %
            % Returns:
            %   mu (2*dim x 1)
            m=this.trigonometricMoment(1);
            mu=reshape([real(m)';imag(m)'],[],1);
        end
        function l = logLikelihood(this,samples)
            % Calculates the log-likelihood of the given samples
            %
            % Parameters:
            %   sampls (dim x n)
            %       n samples
            % Returns:
            %   l (scalar)
            %       log-likelihood of obtaining the given samples
            assert(size(samples,1)==this.dim);
            assert(size(samples,2)>=1);
            
            l = sum(log(this.pdf(samples)));
        end
        function s = sample(this, n)
            % Obtain n samples from the distribution
            % use metropolics hastings by default
            % individual distributions can override this with more
            % sophisticated solutions
            %
            % Parameters:
            %   n (scalar)
            %       number of samples
            % Returns:
            %   s (dim x n)
            %       one sample per column
            s = sampleMetropolisHastings(this, n);
        end
        function s = sampleMetropolisHastings(this, n)
            % Metropolis Hastings sampling algorithm
            %
            % Parameters:
            %   n (scalar)
            %       number of samples
            % Returns:
            %   s (dim x n)
            %       one sample per column
            %
            % Hastings, W. K. 
            % Monte Carlo Sampling Methods Using Markov Chains and Their Applications 
            % Biometrika, 1970, 57, 97-109
            
            burnin = 10;
            skipping = 5;
            
            totalSamples = burnin+n*skipping;
            s = zeros(this.dim,totalSamples);
            x = this.circularMean; % start with mean
            % A better proposal distribution could be obtained by roughly estimating
            % the uncertainty of the true distribution.
            proposal = @(x) mod(x + mvnrnd(zeros(this.dim,1),eye(this.dim))', 2*pi); 
            i=1;
            pdfx = this.pdf(x);
            while i<=totalSamples
                xNew = proposal(x); %generate new sample
                pdfxNew = this.pdf(xNew);
                a = pdfxNew/pdfx;
                if a>1
                    %keep sample
                    s(:,i)=xNew;
                    x = xNew;
                    pdfx = pdfxNew;
                    i=i+1;
                else
                    r = rand(1);
                    if a > r
                        %keep sample
                        s(:,i)=xNew;
                        x = xNew;
                        pdfx = pdfxNew;
                        i=i+1;
                    else
                        %reject sample
                    end
                end
            end
            s = s(:,burnin+1:skipping:end);
        end
        function hd=shift(this,shiftAngles)
            % Shifts the distribution by shiftAngles. If not overloaded,
            % this will return a CustomHypertoroidalDistribution.
            assert(isequal(size(shiftAngles),[this.dim,1]));
            hd=CustomHypertoroidalDistribution(@(xa)this.pdf(xa-repmat(shiftAngles,[1,size(xa,2)])),this.dim);
        end
        function d = squaredDistanceNumerical(this, other)
            % Numerically calculates the squared distance to another distribution
            %
            % Parameters:
            %   other (AbstractCircularDistribution)
            %       distribution to compare to
            % Returns:
            %   d (scalar)
            %       integral over [0,2pi) of squared difference of pdfs
            assert(isa(other, 'AbstractHypertoroidalDistribution'));
            switch this.dim
                case 1
                    d=integral(@(x) (this.pdf(x)-other.pdf(x)).^2, 0, 2*pi);
                case 2
                    d=integral2(...
                        @(x,y)reshape((this.pdf([x(:)';y(:)'])-other.pdf([x(:)';y(:)'])).^2,size(x)),...
                        0,2*pi,0,2*pi);
                case 3
                    d=integral3(...
                        @(x,y,z)reshape((this.pdf([x(:)';y(:)';z(:)'])-other.pdf([x(:)';y(:)';z(:)'])).^2,size(x)),...
                        0,2*pi,0,2*pi,0,2*pi);
                otherwise
                    error('Numerical calculation of squared distance is currently not supported for this dimension.')
            end
        end
        
        function kld = kldNumerical(this, other)
            % Numerically calculates  the Kullback-Leibler divergence to another distribution
            % Be aware that the kld is not symmetric.
            %
            % Parameters:
            %   other (AbstractCircularDistribution)
            %       distribution to compare to
            % Returns:
            %   kld (scalar)
            %       kld of this distribution to other distribution
            assert(isa(other, 'AbstractHypertoroidalDistribution'));
            assert(this.dim==other.dim,'Cannot compare distributions with differing dimensions');
            switch this.dim
                case 1
                    kld=integral(@(x) this.pdf(x).*log(this.pdf(x)./other.pdf(x)), 0, 2*pi);
                case 2
                    kld=integral2(...
                        @(x,y)reshape(this.pdf([x(:)';y(:)']).*log(this.pdf([x(:)';y(:)'])./other.pdf([x(:)';y(:)'])),size(x)),...
                        0,2*pi,0,2*pi);
                case 3
                    kld=integral3(...
                        @(x,y,z)reshape(this.pdf([x(:)';y(:)';z(:)']).*log(this.pdf([x(:)';y(:)';z(:)'])./other.pdf([x(:)';y(:)';z(:)'])),size(x)),...
                        0,2*pi,0,2*pi,0,2*pi);
                otherwise
                    error('Numerical calculation of kld is currently not supported for this dimension.')
            end
        end
        
        function dist=hellingerDistanceNumerical(this, other)
            % Numerically calculates the Hellinger distance to another distribution
            %
            % Parameters:
            %   other (AbstractCircularDistribution)
            %       distribution to compare to
            % Returns:
            %   dist (scalar)
            %       hellinger distance of this distribution to other distribution
            assert(isa(other, 'AbstractHypertoroidalDistribution'));
            assert(this.dim==other.dim,'Cannot compare distributions with differing dimensions');
            switch this.dim
                case 1
                    dist=0.5*integral(@(x)(sqrt(this.pdf(x))-sqrt(other.pdf(x))).^2,0,2*pi);
                case 2
                    dist=0.5*integral2(...
                        @(x,y)reshape((sqrt(this.pdf([x(:)';y(:)']))-sqrt(other.pdf([x(:)';y(:)']))).^2,size(x)),...
                        0,2*pi,0,2*pi);
                case 3
                    dist=0.5*integral3(...
                        @(x,y,z)reshape((sqrt(this.pdf([x(:)';y(:)';z(:)']))-sqrt(other.pdf([x(:)';y(:)';z(:)']))).^2,size(x)),...
                        0,2*pi,0,2*pi,0,2*pi);
                otherwise
                    error('Numerical calculation of Hellinger distance is currently not supported for this dimension.')
            end
        end
        
        function dist=totalVariationDistanceNumerical(this, other)
            % Numerically calculates the total varation distance to another distribution
            %
            % Parameters:
            %   other (AbstractCircularDistribution)
            %       distribution to compare to
            % Returns:
            %   dist (scalar)
            %       total variation distance of this distribution to other distribution
            assert(isa(other, 'AbstractHypertoroidalDistribution'));
            assert(this.dim==other.dim,'Cannot compare distributions with differing dimensions');
            switch this.dim
                case 1
                    dist=0.5*integral(@(x)abs(this.pdf(x)-other.pdf(x)),0,2*pi);
                case 2
                    dist=0.5*integral2(...
                        @(x,y)reshape(abs(this.pdf([x(:)';y(:)'])-other.pdf([x(:)';y(:)'])),size(x)),...
                        0,2*pi,0,2*pi);
                case 3
                    dist=0.5*integral3(...
                        @(x,y,z)reshape(abs(this.pdf([x(:)';y(:)';z(:)'])-other.pdf([x(:)';y(:)';z(:)'])),size(x)),...
                        0,2*pi,0,2*pi,0,2*pi);
                otherwise
                    error('Numerical calculation of total variation distance is currently not supported for this dimension.')
            end
        end
    end
end