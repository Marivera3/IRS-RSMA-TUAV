% clear all; 
% % name = 'PSred_RSMA_SCA';
% seed_value = 1;
% pp = 0; N_R = 128; % totalJointIters = 20;
% fileID = fopen(sprintf('logs/RSMA_comparison_logs/log_seed_%d_%s.txt', seed_value, name),'w');
% fileID = 1;
initialise_params_TUAVv2;
% weights
u_k = ones(K, 1);
% Threshold rate
% Rth = 0*ones(K, 1);
epsilonRSMA = 1e-6;
epsilonPS = 1e-4;
maxIter = 1000;

RSMAoptCell = {};
PSoptCell = {};

name = sprintf('JointOptimisation_PS-SCA_RSMA-WMMSE_%dRth%d_NR_%d', floor(Rth(1)), round(mod(Rth(1), 1)*10), N_R);
fileID = fopen(sprintf('logs/JointOptimisation/log_seed_%d_%s.txt', seed_value, name),'w');
iter = 1;
loop = 1;
while loop


%% Phase shift

fprintf(fileID, '\n');
fprintf(fileID, '##########  PS  ##########\n');
fprintf(fileID, '\n');

try
    [PSoptStructureSCAred, PSloopSCAred, PSiterationsSCAred, PStimeElapsedSCAred] = ...
            Optimisation_Update_PhaseShift(s, h_T_U_PL, h_R_U_PL, G, K, ...
        varianceNoise, p_c_IC, p_k_IC, N_R, Rth, u_k, common_rates, epsilonPS, maxIter, fileID);
    s = PSoptStructureSCAred(PSiterationsSCAred).phaseshifts;
    PSoptCell{iter} = {PSoptStructureSCAred(1:PSiterationsSCAred), PSloopSCAred, PSiterationsSCAred, PStimeElapsedSCAred};
catch ME
    disp(ME)
    fprintf(fileID, 'Infeasible.\n');
end

% if PSoptStructureSCAred(PSiterationsSCAred).PSgt1 > 0
%     break
% end
%% RSMA MMSE
fprintf(fileID, '\n');
fprintf(fileID, '##########  RSMA  ##########\n');
fprintf(fileID, '\n');
Theta = diag(s);
h_ov_k = (h_T_U_PL' + h_R_U_PL' * Theta * G)';
% tau = trace(p_k_IC*p_k_IC')/Pt;
if iter == 1
    p_c_IC = AMBF_common_precoder(h_ov_k, Pt, tau);
%     p_c_IC = SVD_common_precoder(h_ov_k, Pt, tau);
    p_k_IC = RZF_private_precoder_matrix(h_ov_k, Pt, K, tau, N_T);
    % p_k_IC = MRT_precoder_private_matrix(h_ov_k, Pt, K, tau);
end

try
    [RSMAoptStructureWMMSE, RSMAloopWMMSE, RSMAiterationsWMMSE, timeElapsedWMMSE] = ...
            Optimisation_Update_RSMAparameters_WMMSE(h_ov_k, K, ...
            varianceNoise, p_c_IC, p_k_IC, Pt, N_T, Rth, u_k, epsilonRSMA, maxIter, fileID);
    p_c_IC = RSMAoptStructureWMMSE(RSMAiterationsWMMSE).Pc;
    p_k_IC = RSMAoptStructureWMMSE(RSMAiterationsWMMSE).Pk;
    RSMAoptCell{iter} = {RSMAoptStructureWMMSE(1:RSMAiterationsWMMSE), RSMAloopWMMSE, RSMAiterationsWMMSE, timeElapsedWMMSE};
    common_rates = RSMAoptStructureWMMSE(RSMAiterationsWMMSE).Cc;
catch ME
    disp(ME)
    fprintf(fileID, 'Infeasible.\n');
end


%%
try
    if iter > 1
        RSMAconvergence =  abs(RSMAoptCell{iter}{1}(end).Rov - RSMAoptCell{iter-1}{1}(end).Rov) <= epsilonRSMA;
        PSconvergence   =  abs(PSoptCell{iter}{1}(end).Rov - PSoptCell{iter-1}{1}(end).Rov) <= epsilonPS;
        if RSMAconvergence && PSconvergence
            loop = 0;
        end
    
    end
    fprintf('iter: %d, PS-Rov=%.8f, RSMA-Rov=%.8f\n', iter, PSoptStructureSCAred(PSiterationsSCAred).Rov, RSMAoptStructureWMMSE(RSMAiterationsWMMSE).Rov)
catch ME
    disp(ME)
    fprintf(fileID, 'CVX non-return.\n');
    fprintf(fileID, '\n');
    fprintf(fileID, '##########  END  ##########\n');
    fprintf(fileID, '\n');
    fclose(fileID);
    loop = 0;
end


if iter > totalJointIters
    loop = 0;
end


iter = iter + 1;



%% save workspace and close log
end
fprintf(fileID, '\n');
fprintf(fileID, '##########  END  ##########\n');
fprintf(fileID, '\n');
fclose(fileID);
name_matfile = sprintf('logs/JointOptimisation/log_seed_%d_%s.mat', seed_value, name);
save(name_matfile)