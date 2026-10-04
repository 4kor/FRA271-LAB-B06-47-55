function weight_g = loadcell_weight_piecewise(voltage_V)
%#codegen
% Paste this function into a Simulink MATLAB Function block.
% Input: voltage in V after a causal low-pass filter. Output: mass in g.
% Experimental calibration: data3.mat, Trials 2/3, middle 60%, 2 Hz filter.
% Boundary 0.25 V was chosen provisionally, not proven physically.
% Calibrated mean input range is approximately 0.0085 to 2.4214 V.
% Do not extrapolate far outside this range. No clipping/tare is applied.
m = 417.242575653;
b = 23.8912825353;
s = 253.990292766;
k = -5.47759571166;
vb = 0.25;

weight_g = m .* voltage_V + b;
low = voltage_V < vb;
weight_g(low) = m*vb + b + (s/k) .* ...
    (exp(k .* (voltage_V(low)-vb)) - 1);
end
