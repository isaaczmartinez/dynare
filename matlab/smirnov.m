function [H,prob,d] = smirnov(x1 , x2 , alpha, iflag )
% Smirnov test for 2 distributions
%   [H,prob,d] = smirnov(x1 , x2 , alpha, iflag )
%
% Part of the Sensitivity Analysis Toolbox for DYNARE
%
% Written by Marco Ratto, 2006
% Joint Research Centre, The European Commission,
% (http://eemc.jrc.ec.europa.eu/),
% marco.ratto@jrc.it 
%
% Disclaimer: This software is not subject to copyright protection and is in the public domain. 
% It is an experimental system. The Joint Research Centre of European Commission 
% assumes no responsibility whatsoever for its use by other parties
% and makes no guarantees, expressed or implied, about its quality, reliability, or any other
% characteristic. We would appreciate acknowledgement if the software is used.
% Reference:
% M. Ratto, Global Sensitivity Analysis for Macroeconomic models, MIMEO, 2006.
%



if nargin<3
    alpha  =  0.05;
end
if nargin<4,
    iflag=0;
end

% empirical cdfs.
xmix= [x1;x2];
bin = [-inf ; sort(xmix) ; inf];

ncount1 = histc (x1 , bin);
ncount2 = histc (x2 , bin);

cum1  =  cumsum(ncount1)./sum(ncount1);
cum1  =  cum1(1:end-1);

cum2  =  cumsum(ncount2)./sum(ncount2);
cum2  =  cum2(1:end-1);

n1=  length(x1);
n2=  length(x2);
n =  n1*n2 /(n1+n2);

% Compute the d(n1,n2) statistics.

if iflag==0,
    d  =  max(abs(cum1 - cum2));
elseif iflag==-1
    d  =  max(cum2 - cum1);
elseif iflag==1
    d  =  max(cum1 - cum2);
end
%
% Compute P-value check H0 hypothesis
%

lam =  max((sqrt(n) + 0.12 + 0.11/sqrt(n)) * d , 0);
if iflag == 0        
    j       =  [1:101]';
    prob  =  2 * sum((-1).^(j-1).*exp(-2*lam*lam*j.^2));
    
    prob=max(prob,0);
    prob=min(1,prob);
else
    prob  =  exp(-2*lam*lam);
end

H  =  (alpha >= prob);
