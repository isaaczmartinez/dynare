function x0 = stab_map_(Nsam, fload, alpha2, alpha)
%
% function x0 = stab_map_(Nsam, fload, alpha2, alpha)
%
% Mapping of stability regions in the prior ranges applying
% Monte Carlo filtering techniques.
%
% M. Ratto, Global Sensitivity Analysis for Macroeconomic models
% I. Mapping stability, MIMEO, 2005.
%
% INPUTS
% Nsam = MC sample size
% fload = 0 to run new MC; 1 to load prevoiusly generated analysis
% alpha2 =  significance level for bivariate sensitivity analysis
% [abs(corrcoef) > alpha2]
% alpha =  significance level for univariate sensitivity analysis 
%  (uses smirnov)
%
% OUTPUT: 
% x0: one parameter vector for which the model is stable.
%
% GRAPHS
% 1) Histograms of marginal distributions under the stability regions
% 2) Cumulative distributions of: 
%   - stable subset (dotted lines) 
%   - unstable subset (solid lines)
% 3) Bivariate plots of significant correlation patterns 
%  ( abs(corrcoef) > alpha2) under the stable subset
%
% USES lptauSEQ, 
%      smirnov
%
% Copyright (C) 2005 Marco Ratto
% THIS PROGRAM WAS WRITTEN FOR MATLAB BY
% Marco Ratto,
% Unit of Econometrics and Statistics AF
% (http://www.jrc.cec.eu.int/uasa/),
% IPSC, Joint Research Centre
% The European Commission,
% TP 361, 21020 ISPRA(VA), ITALY
% marco.ratto@jrc.it 
%
% ALL COPIES MUST BE PROVIDED FREE OF CHARGE AND MUST INCLUDE THIS COPYRIGHT
% NOTICE.
%

%global bayestopt_ estim_params_ dr_ options_ ys_ fname_
global bayestopt_ estim_params_ options_ oo_ M_

ys_ = oo_.dr.ys;
dr_ = oo_.dr;
fname_ = M_.fname;

nshock = estim_params_.nvx;
nshock = nshock + estim_params_.nvn;
nshock = nshock + estim_params_.ncx;
nshock = nshock + estim_params_.ncn;
number_of_grid_points = 2^9;      % 2^9 = 512 !... Must be a power of two.
bandwidth = 0;                    % Rule of thumb optimal bandwidth parameter.
kernel_function = 'gaussian';     % Gaussian kernel for Fast Fourrier Transform approximaton.  
%kernel_function = 'uniform';     % Gaussian kernel for Fast Fourrier Transform approximaton.  


if nargin==0,
    Nsam=2000; %2^13; %256;
end
if nargin<2,
    fload=0;
end
if nargin<4,
    alpha=0.002;
end
if nargin<3,
    alpha2=0.3;
end

if fload==0 | nargin<2 | isempty(fload),
    if estim_params_.np<52,
        [lpmat] = lptauSEQ(Nsam,estim_params_.np);
    else
        %[lpmat] = rand(Nsam,estim_params_.np);
        for j=1:estim_params_.np,
            lpmat(:,j) = randperm(Nsam)'./(Nsam+1); %latin hypercube
        end
    end
    
    
    for j=1:estim_params_.np,
        if estim_params_.np>30 & estim_params_.np<52 
            lpmat(:,j)=lpmat(randperm(Nsam),j).*(bayestopt_.ub(j+nshock)-bayestopt_.lb(j+nshock))+bayestopt_.lb(j+nshock);
        else
            lpmat(:,j)=lpmat(:,j).*(bayestopt_.ub(j+nshock)-bayestopt_.lb(j+nshock))+bayestopt_.lb(j+nshock);
        end
    end
    % 
    h = waitbar(0,'Please wait...');
    options_.periods=0;
    options_.nomoments=1;
    options_.irf=0;
    options_.noprint=1;
    for j=1:Nsam,
%         for i=1:estim_params_.np,
%             evalin('base',[bayestopt_.name{i+nshock}, '= ',sprintf('%0.15e',lpmat(j,i)),';'])
%         end
        M_.params(estim_params_.param_vals(:,1)) = lpmat(j,:)';
        %evalin('base','stoch_simul(var_list_);');
        stoch_simul([]);
        dr_ = oo_.dr;
        %egg(:,j) = sort(eigenvalues_);
        %egg(:,j) = sort(dr_.eigval);
        if isfield(dr_,'eigval'),
            egg(:,j) = sort(dr_.eigval);
        else
            egg(:,j)=ones(size(egg,1),1).*1.1;
        end
        ys_=real(dr_.ys);
        yys(:,j) = ys_;
        ys_=yys(:,1);
        waitbar(j/Nsam,h,['MC iteration ',int2str(j),'/',int2str(Nsam)])
    end
    close(h)
    
    % map stable samples
    ix=[1:Nsam];
    for j=1:Nsam,
        if abs(egg(dr_.npred,j))>=options_.qz_criterium; %(1-(options_.qz_criterium-1)); %1-1.e-5;
            ix(j)=0;
        elseif (dr_.nboth | dr_.nfwrd) & abs(egg(dr_.npred+1,j))<=options_.qz_criterium; %1+1.e-5;
            ix(j)=0;
        end
    end
    ix=ix(find(ix));  % stable params
    
    % map unstable samples
    ixx=[1:Nsam];
    for j=1:Nsam,
        %if abs(egg(dr_.npred+1,j))>1+1.e-5 & abs(egg(dr_.npred,j))<1-1.e-5;
        if (dr_.nboth | dr_.nfwrd),
            if abs(egg(dr_.npred+1,j))>options_.qz_criterium & abs(egg(dr_.npred,j))<options_.qz_criterium; %(1-(options_.qz_criterium-1));
                ixx(j)=0;
            end
        else
            if abs(egg(dr_.npred,j))<options_.qz_criterium; %(1-(options_.qz_criterium-1));
                ixx(j)=0;
            end
        end
    end
    ixx=ixx(find(ixx));   % unstable params
    save([fname_,'_stab'],'lpmat','ixx','ix','egg','yys')
else
    load([fname_,'_stab'])
    Nsam = size(lpmat,1);    
end

delete([fname_,'_stab_*.*']);
delete([fname_,'_stab_SA_*.*']);
delete([fname_,'_stab_corr_*.*']);
delete([fname_,'_unstab_corr_*.*']);

if length(ixx)>0 & length(ixx)<Nsam,
% Blanchard Kahn
for i=1:ceil(estim_params_.np/12),
    figure,
    for j=1+12*(i-1):min(estim_params_.np,12*i),
        subplot(3,4,j-12*(i-1))
        optimal_bandwidth = mh_optimal_bandwidth(lpmat(ix,j),length(ix),bandwidth,kernel_function); 
        [x1,f1] = kernel_density_estimate(lpmat(ix,j),number_of_grid_points,...
            optimal_bandwidth,kernel_function);
        plot(x1, f1,':k','linewidth',2)
        optimal_bandwidth = mh_optimal_bandwidth(lpmat(ixx,j),length(ixx),bandwidth,kernel_function); 
        [x1,f1] = kernel_density_estimate(lpmat(ixx,j),number_of_grid_points,...
            optimal_bandwidth,kernel_function);
        hold on, plot(x1, f1,'k','linewidth',2)

        %hist(lpmat(ix,j),30)
        title(bayestopt_.name{j+nshock})
    end
    saveas(gcf,[fname_,'_stab_',int2str(i)])
end

% Smirnov test for Blanchard; 
for i=1:ceil(estim_params_.np/12),
    figure,
    for j=1+12*(i-1):min(estim_params_.np,12*i),
        subplot(3,4,j-12*(i-1))
        if ~isempty(ix),
            h=cumplot(lpmat(ix,j));
            set(h,'color',[0 0 0], 'linestyle',':')
        end
        hold on,
        if ~isempty(ixx),
             h=cumplot(lpmat(ixx,j));
             set(h,'color',[0 0 0])
        end
%         if exist('kstest2')==2 & length(ixx)>0 & length(ixx)<Nsam,
%             [H,P,KSSTAT] = kstest2(lpmat(ix,j),lpmat(ixx,j));
%             title([bayestopt_.name{j+nshock},'. K-S prob ', num2str(P)])
%         else
            [H,P,KSSTAT] = smirnov(lpmat(ix,j),lpmat(ixx,j));
            title([bayestopt_.name{j+nshock},'. K-S prob ', num2str(P)])
%         end
    end
    saveas(gcf,[fname_,'_stab_SA_',int2str(i)])
end


disp(' ')
disp(' ')
disp('Starting bivariate analysis:')

c0=corrcoef(lpmat(ix,:));
c00=tril(c0,-1);

    stab_map_2(lpmat(ix,:),alpha2, 1);
    stab_map_2(lpmat(ixx,:),alpha2, 0);
    
else
    if length(ixx)==0,
        disp('All parameter values in the prior ranges are stable!')
    else
        disp('All parameter values in the prior ranges are unstable!')        
    end

end


% % optional map cyclicity of dominant eigenvalues, if
% thex=[];
% for j=1:Nsam,
%     %cyc(j)=max(abs(imag(egg(1:34,j))));
%     ic = find(imag(egg(1:dr_.npred,j)));
%     i=find( abs(egg( ic ,j) )>0.9); %only consider complex dominant eigenvalues 
%     if ~isempty(i),
%         i=i(1:2:end);
%         thedum=[];
%         for ii=1:length(i),
%             idum = ic( i(ii) );
%             thedum(ii)=abs(angle(egg(idum,j)));
%         end
%         [dum, icx]=max(thedum);
%         icy(j) = ic( i(icx) );
%         thet(j)=max(thedum);
%         if thet(j)<0.05 & find(ix==j),  % keep stable runs with freq smaller than 0.05 
%             thex=[thex; j];
%         end
%     else
%         if find(ix==j),
%             thex=[thex; j];
%         end
%     end
% end
% % cyclicity
% for i=1:ceil(estim_params_.np/12),
%     figure,
%     for j=1+12*(i-1):min(estim_params_.np,12*i),
%         subplot(3,4,j-12*(i-1))
%         hist(lpmat(thex,j),30)
%         title(bayestopt_.name{j+nshock})
%     end
% end
% 
% % TFP STEP & Blanchard; & cyclicity
% for i=1:ceil(estim_params_.np/12),
%     figure,
%     for j=1+12*(i-1):min(estim_params_.np,12*i),
%         [H,P,KSSTAT] = kstest2(lpmat(1:Nsam,j),lpmat(ixx,j));
%         subplot(3,4,j-12*(i-1))
%         cdfplot(lpmat(1:Nsam,j))
%         hold on,
%         cdfplot(lpmat(ixx,j))
%         title([bayestopt_.name{j+nshock},'. K-S prob ', num2str(P)])
%     end
% end

x0=0.5.*(bayestopt_.ub(1:nshock)-bayestopt_.lb(1:nshock))+bayestopt_.lb(1:nshock);
x0 = [x0; lpmat(ix(1),:)'];
