%% =========================================================================
% Second-Order System Response Calculator with Controller Design
% Interactive control system analysis with controller options
% =========================================================================
%
% Analyses a 2nd order system with optional controllers
% Displays: Step Response, Impulse Response, Bode Plot, System Info
%
% Features:
% - Toggle between Slider and Text input modes
% - 5 input methods for system specification
% - 3 controller types: None, PID, State Feedback
% - Toggle between Plant and Controller parameter views
% - Real-time closed-loop response visualization
%
% =========================================================================

close all; clear all; clc;

%% CONFIG: Define calculator parameters

CALCULATOR_NAME = 'System Response with Controller';
CALCULATOR_VERSION = '3.0';

% Define input methods for plant
input_methods = {'Time Constant (1st Order)', 'Natural Frequency & Damping', 'ODE Coefficients', 'Laplace Transfer Function', 'State Space Matrix'};

% Define controller types
controller_types = {'None', 'PID Controller', 'State Feedback'};

% Define parameters for each plant input method
params_method1 = struct( ...
    'name', {'Time Constant (s)', 'DC Gain'}, ...
    'label', {'tau', 'K'}, ...
    'min', {0.01, 0.05}, ...
    'max', {50, 20}, ...
    'init', {1, 1}, ...
    'step', {0.01, 0.1} ...
);

params_method2 = struct( ...
    'name', {'Natural Frequency (rad/s)', 'Damping Ratio', 'DC Gain'}, ...
    'label', {'wn', 'zeta', 'K'}, ...
    'min', {0.1, 0, 0.05}, ...
    'max', {50, 5, 20}, ...
    'init', {5, 0.7, 1}, ...
    'step', {0.1, 0.01, 0.1} ...
);

params_method3 = struct( ...
    'name', {'a2 (coefficient of y'''')', 'a1 (coefficient of y'')', 'a0 (coefficient of y)', 'b (coefficient of u)'}, ...
    'label', {'a2', 'a1', 'a0', 'b'}, ...
    'min', {0, 0, 0, 0}, ...
    'max', {10, 50, 500, 100}, ...
    'init', {1, 7, 25, 25}, ...
    'step', {0.1, 0.1, 0.5, 0.5} ...
);

params_method4 = struct( ...
    'name', {'Numerator b0', 'Denominator a2', 'Denominator a1', 'Denominator a0'}, ...
    'label', {'b0', 'a2', 'a1', 'a0'}, ...
    'min', {0.1, 0.1, 0, 0.1}, ...
    'max', {200, 10, 50, 500}, ...
    'init', {25, 1, 7, 25}, ...
    'step', {0.5, 0.1, 0.1, 0.5} ...
);

params_method5 = struct( ...
    'name', {'A[1,1]', 'A[1,2]', 'A[2,1]', 'A[2,2]'}, ...
    'label', {'A11', 'A12', 'A21', 'A22'}, ...
    'min', {-10, 1, -50, -50}, ...
    'max', {10, 200, -0.05, 0}, ...
    'init', {0, 25, -1, -7}, ...
    'step', {0.1, 0.1, 0.1, 0.1} ...
);

% Define PID controller parameters
params_pid = struct( ...
    'name', {'Proportional Gain (Kp)', 'Integral Gain (Ki)', 'Derivative Gain (Kd)'}, ...
    'label', {'Kp', 'Ki', 'Kd'}, ...
    'min', {0, 0, 0}, ...
    'max', {100, 50, 20}, ...
    'init', {1, 0, 0}, ...
    'step', {0.1, 0.1, 0.1} ...
);

% Define state feedback parameters (2 gains for 2-state system)
params_statefb = struct( ...
    'name', {'State Feedback K1', 'State Feedback K2'}, ...
    'label', {'K1', 'K2'}, ...
    'min', {-100, -100}, ...
    'max', {100, 100}, ...
    'init', {1, 1}, ...
    'step', {0.1, 0.1} ...
);

% Initialize state
current_method = 1;
input_mode = 'slider';
controller_type = 1;  % 1=None, 2=PID, 3=State Feedback
param_view = 'plant';  % 'plant' or 'controller'

%% Initialize figure and layout
fig = figure('Name', CALCULATOR_NAME, 'NumberTitle', 'off');
set(fig, 'Position', [50, 50, 1400, 900]);
set(fig, 'Color', [0.94 0.94 0.94]);

%% Create input mode radio buttons (at the top)
y_mode_toggle = 870;

radio_slider = uicontrol('Style', 'radiobutton', ...
    'String', 'Sliders', ...
    'Position', [15, y_mode_toggle, 100, 22], ...
    'FontSize', 10, ...
    'Value', 1, ...
    'Callback', @inputModeCallback);

radio_text = uicontrol('Style', 'radiobutton', ...
    'String', 'Text Fields', ...
    'Position', [120, y_mode_toggle, 100, 22], ...
    'FontSize', 10, ...
    'Value', 0, ...
    'Callback', @inputModeCallback);

% Divider line
uicontrol('Style', 'text', ...
    'Position', [10, y_mode_toggle-15, 240, 2], ...
    'BackgroundColor', [0.7 0.7 0.7]);

%% Button controls at the top
y_buttons = y_mode_toggle - 60;

uicontrol('Style', 'pushbutton', ...
    'String', 'Reset', ...
    'Position', [15, y_buttons, 110, 32], ...
    'FontSize', 10, ...
    'FontWeight', 'bold', ...
    'Callback', @resetCallback);

uicontrol('Style', 'pushbutton', ...
    'String', 'Export', ...
    'Position', [135, y_buttons, 110, 32], ...
    'FontSize', 10, ...
    'FontWeight', 'bold', ...
    'Callback', @exportCallback);

% Divider line after buttons
uicontrol('Style', 'text', ...
    'Position', [10, y_buttons-10, 240, 2], ...
    'BackgroundColor', [0.7 0.7 0.7]);

%% Create plant input method dropdown
y_dropdown = y_buttons - 80;

%% Create PLANT parameter controls
y_plant_header = y_dropdown + 30;
uicontrol('Style', 'text', ...
    'String', 'PLANT', ...
    'Position', [10, y_plant_header, 240, 22], ...
    'HorizontalAlignment', 'center', ...
    'FontSize', 10, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.85 0.90 0.95], ...
    'ForegroundColor', [0.2 0.2 0.5]);

y_dropdown = y_plant_header - 35;

dropdown = uicontrol('Style', 'popupmenu', ...
    'String', input_methods, ...
    'Position', [15, y_dropdown, 230, 25], ...
    'FontSize', 10, ...
    'Value', current_method, ...
    'Callback', @inputMethodCallback);

max_params = 9;
plant_slider_handles = zeros(1, max_params);
plant_text_handles = zeros(1, max_params);
plant_value_text_handles = zeros(1, max_params);
plant_label_handles = zeros(1, max_params);

x_start = 15;
y_start = y_dropdown - 30;
control_spacing = 58;

for i = 1:max_params
    y_pos = y_start - (i-1) * control_spacing;

    label = uicontrol('Style', 'text', ...
        'String', '', ...
        'Position', [x_start, y_pos, 230, 20], ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 9.5, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'Visible', 'off');

    slider = uicontrol('Style', 'slider', ...
        'Min', 0, 'Max', 1, ...
        'Value', 0.5, ...
        'Position', [x_start, y_pos-22, 230, 20], ...
        'Tag', '', ...
        'SliderStep', [0.01, 0.1], ...
        'Callback', @plantSliderCallback, ...
        'Visible', 'off');

    text_input = uicontrol('Style', 'edit', ...
        'String', '', ...
        'Position', [x_start, y_pos-22, 230, 22], ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, 'BackgroundColor', [1 1 1], ...
        'Callback', @plantValueEditCallback, ...
        'Visible', 'off');

    value_text = uicontrol('Style', 'text', ...
        'String', '', ...
        'Position', [x_start, y_pos-42, 230, 18], ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 9, ...
        'BackgroundColor', [0.88 0.92 0.98], ...
        'ForegroundColor', [0.2 0.2 0.6], ...
        'Visible', 'off');

    plant_slider_handles(i) = slider;
    plant_text_handles(i) = text_input;
    plant_value_text_handles(i) = value_text;
    plant_label_handles(i) = label;
end

%% Create CONTROLLER parameter controls
y_ctrl_header = 360;

% Divider line before controller section
uicontrol('Style', 'text', ...
    'Position', [10, y_ctrl_header+35, 240, 2], ...
    'BackgroundColor', [0.7 0.7 0.7]);

uicontrol('Style', 'text', ...
    'String', 'CONTROLLER', ...
    'Position', [10, y_ctrl_header, 240, 22], ...
    'HorizontalAlignment', 'center', ...
    'FontSize', 10, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.95 0.90 0.85], ...
    'ForegroundColor', [0.5 0.2 0.2]);

y_controller_dropdown = y_ctrl_header - 45;

controller_dropdown = uicontrol('Style', 'popupmenu', ...
    'String', controller_types, ...
    'Position', [15, y_controller_dropdown, 230, 25], ...
    'FontSize', 10, ...
    'Value', controller_type, ...
    'Callback', @controllerTypeCallback);

max_controller_params = 3;
controller_slider_handles = zeros(1, max_controller_params);
controller_text_handles = zeros(1, max_controller_params);
controller_value_text_handles = zeros(1, max_controller_params);
controller_label_handles = zeros(1, max_controller_params);

y_ctrl_start = y_controller_dropdown - 35;

for i = 1:max_controller_params
    y_pos = y_ctrl_start - (i-1) * control_spacing;

    label = uicontrol('Style', 'text', ...
        'String', '', ...
        'Position', [x_start, y_pos, 230, 20], ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 9.5, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.94 0.94 0.94], ...
        'Visible', 'off');

    slider = uicontrol('Style', 'slider', ...
        'Min', 0, 'Max', 1, ...
        'Value', 0.5, ...
        'Position', [x_start, y_pos-22, 230, 20], ...
        'Tag', '', ...
        'SliderStep', [0.01, 0.1], ...
        'Callback', @controllerSliderCallback, ...
        'Visible', 'off');

    text_input = uicontrol('Style', 'edit', ...
        'String', '', ...
        'Position', [x_start, y_pos-22, 230, 22], ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, 'BackgroundColor', [1 1 1], ...
        'Callback', @controllerValueEditCallback, ...
        'Visible', 'off');

    value_text = uicontrol('Style', 'text', ...
        'String', '', ...
        'Position', [x_start, y_pos-42, 230, 18], ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 9, ...
        'BackgroundColor', [0.98 0.92 0.88], ...
        'ForegroundColor', [0.6 0.2 0.2], ...
        'Visible', 'off');

    controller_slider_handles(i) = slider;
    controller_text_handles(i) = text_input;
    controller_value_text_handles(i) = value_text;
    controller_label_handles(i) = label;
end

ss_note = uicontrol('Style', 'text', ...
    'String', {'State Space: B=[0;1], C=[1,0], D=0'}, ...
    'Position', [15, 410, 230, 18], ...
    'HorizontalAlignment', 'center', ...
    'FontSize', 8, ...
    'ForegroundColor', [0.4, 0.4, 0.6], ...
    'BackgroundColor', [0.95 0.95 1], ...
    'Visible', 'off');

%% Info text area at bottom
info_text = uicontrol('Style', 'text', ...
    'String', 'System Info', ...
    'Position', [10, 5, 240, 80], ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 8, ...
    'BackgroundColor', [1 1 0.9], ...
    'ForegroundColor', [0.3 0.3 0.3]);

%% Create axes for plots
% Slightly more left padding from parameter panel, less right padding, maintain gap between plots
ax1 = axes('Position', [0.23, 0.53, 0.35, 0.40], 'Tag', 'plot1');
ax2 = axes('Position', [0.62, 0.53, 0.35, 0.40], 'Tag', 'plot2');
ax3_mag = axes('Position', [0.23, 0.05, 0.35, 0.40], 'Tag', 'plot3_mag');
ax3_phase = axes('Position', [0.62, 0.05, 0.35, 0.40], 'Tag', 'plot3_phase');

%% Store handles
handles = struct();
handles.plant_sliders = plant_slider_handles;
handles.plant_text_inputs = plant_text_handles;
handles.plant_value_texts = plant_value_text_handles;
handles.plant_labels = plant_label_handles;
handles.controller_sliders = controller_slider_handles;
handles.controller_text_inputs = controller_text_handles;
handles.controller_value_texts = controller_value_text_handles;
handles.controller_labels = controller_label_handles;
handles.ss_note = ss_note;
handles.dropdown = dropdown;
handles.controller_dropdown = controller_dropdown;
handles.radio_slider = radio_slider;
handles.radio_text = radio_text;
handles.info_text = info_text;
handles.axes = [ax1, ax2, ax3_mag, ax3_phase];
handles.fig = fig;
handles.current_method = current_method;
handles.input_mode = input_mode;
handles.controller_type = controller_type;
handles.params_method1 = params_method1;
handles.params_method2 = params_method2;
handles.params_method3 = params_method3;
handles.params_method4 = params_method4;
handles.params_method5 = params_method5;
handles.params_pid = params_pid;
handles.params_statefb = params_statefb;
set(fig, 'UserData', handles);

% Initialize UI
try
    updateUIControls(fig);
catch err
    fprintf('ERROR in updateUIControls: %s\n', err.message);
end

drawnow();

% Initial plot
try
    updatePlots(fig);
catch err
    fprintf('Error in updatePlots: %s\n', err.message);
end

%% =========================================================================
% CALLBACK FUNCTIONS
% =========================================================================

function inputModeCallback(src, event)
    fig = gcbf;
    handles = get(fig, 'UserData');
    
    % Get current plant values
    plant_params = getPlantParameters(fig);
    plant_values = [];
    old_mode = handles.input_mode;
    
    for i = 1:length(handles.plant_labels)
        if strcmp(get(handles.plant_labels(i), 'Visible'), 'on')
            if strcmp(old_mode, 'slider')
                raw_value = get(handles.plant_sliders(i), 'Value');
                plant_values(end+1) = round(raw_value * 10) / 10;
            else
                raw_str = get(handles.plant_text_inputs(i), 'String');
                raw_value = str2double(raw_str);
                if isnan(raw_value)
                    raw_value = plant_params(i).init;
                end
                plant_values(end+1) = raw_value;
            end
        end
    end
    
    % Get current controller values
    controller_params = getControllerParameters(fig);
    controller_values = [];
    if ~isempty(controller_params)
        for i = 1:length(handles.controller_labels)
            if strcmp(get(handles.controller_labels(i), 'Visible'), 'on')
                if strcmp(old_mode, 'slider')
                    raw_value = get(handles.controller_sliders(i), 'Value');
                    controller_values(end+1) = round(raw_value * 10) / 10;
                else
                    raw_str = get(handles.controller_text_inputs(i), 'String');
                    raw_value = str2double(raw_str);
                    if isnan(raw_value)
                        raw_value = controller_params(i).init;
                    end
                    controller_values(end+1) = raw_value;
                end
            end
        end
    end
    
    % Update mode
    if src == handles.radio_slider
        handles.input_mode = 'slider';
        set(handles.radio_slider, 'Value', 1);
        set(handles.radio_text, 'Value', 0);
    else
        handles.input_mode = 'text';
        set(handles.radio_slider, 'Value', 0);
        set(handles.radio_text, 'Value', 1);
    end
    
    set(fig, 'UserData', handles);
    updateUIControls(fig);
    
    % Restore plant values
    if ~isempty(plant_values)
        for i = 1:length(plant_values)
            if i <= length(handles.plant_sliders)
                if strcmp(handles.input_mode, 'slider')
                    rounded_val = round(plant_values(i) * 10) / 10;
                    set(handles.plant_sliders(i), 'Value', rounded_val);
                    set(handles.plant_value_texts(i), 'String', sprintf('%s = %.1f', plant_params(i).label, rounded_val));
                else
                    set(handles.plant_text_inputs(i), 'String', sprintf('%.6g', plant_values(i)));
                    set(handles.plant_value_texts(i), 'String', sprintf('%s = %.6g', plant_params(i).label, plant_values(i)));
                end
            end
        end
    end
    
    % Restore controller values
    if ~isempty(controller_values) && ~isempty(controller_params)
        for i = 1:length(controller_values)
            if i <= length(handles.controller_sliders)
                if strcmp(handles.input_mode, 'slider')
                    rounded_val = round(controller_values(i) * 10) / 10;
                    set(handles.controller_sliders(i), 'Value', rounded_val);
                    set(handles.controller_value_texts(i), 'String', sprintf('%s = %.1f', controller_params(i).label, rounded_val));
                else
                    set(handles.controller_text_inputs(i), 'String', sprintf('%.6g', controller_values(i)));
                    set(handles.controller_value_texts(i), 'String', sprintf('%s = %.6g', controller_params(i).label, controller_values(i)));
                end
            end
        end
    end
    
    updatePlots(fig);
end

function controllerTypeCallback(src, event)
    fig = gcbf;
    handles = get(fig, 'UserData');
    
    handles.controller_type = get(src, 'Value');
    set(fig, 'UserData', handles);
    
    % Only update controller parameter controls, not plant parameters
    updateControllerUIControls(fig);
    updatePlots(fig);
end

function inputMethodCallback(src, event)
    fig = gcbf;
    handles = get(fig, 'UserData');
    
    new_method = get(src, 'Value');
    old_method = handles.current_method;
    
    % Only try conversion if both methods support it
    if new_method ~= 1 && old_method ~= 1 && old_method ~= 5
        params = getPlantParameters(fig);
        current_values = [];
        
        for i = 1:length(handles.plant_sliders)
            if strcmp(get(handles.plant_labels(i), 'Visible'), 'on')
                if strcmp(handles.input_mode, 'slider')
                    raw_value = get(handles.plant_sliders(i), 'Value');
                    current_values(end+1) = round(raw_value * 10) / 10;
                else
                    raw_str = get(handles.plant_text_inputs(i), 'String');
                    raw_value = str2double(raw_str);
                    if isnan(raw_value)
                        raw_value = params(i).init;
                    end
                    current_values(end+1) = raw_value;
                end
            end
        end
        
        if ~isempty(current_values)
            [~, ~, wn, zeta, K] = convertToTransferFunction(current_values, old_method);
        else
            wn = 5; zeta = 0.7; K = 1;
        end
        
        new_values = convertFromTransferFunction(wn, zeta, K, new_method);
    else
        new_values = [];
    end
    
    handles.current_method = new_method;
    set(fig, 'UserData', handles);
    
    updateUIControls(fig);
    
    if ~isempty(new_values)
        num_params = length(new_values);
        params = getPlantParameters(fig);
        for i = 1:num_params
            if i <= length(handles.plant_sliders)
                if strcmp(handles.input_mode, 'slider')
                    rounded_val = round(new_values(i) * 10) / 10;
                    set(handles.plant_sliders(i), 'Value', rounded_val);
                    set(handles.plant_value_texts(i), 'String', sprintf('%s = %.1f', params(i).label, rounded_val));
                else
                    set(handles.plant_text_inputs(i), 'String', sprintf('%.6g', new_values(i)));
                    set(handles.plant_value_texts(i), 'String', sprintf('%s = %.6g', params(i).label, new_values(i)));
                end
            end
        end
    end
    
    updatePlots(fig);
end

function updateUIControls(fig)
    if nargin < 1
        fig = gcf;
    end
    handles = get(fig, 'UserData');
    
    if isempty(handles)
        error('Handles not initialized');
    end
    
    % Update PLANT parameters
    plant_params = getPlantParameters(fig);
    num_plant_params = length(plant_params);
    is_slider_mode = strcmp(handles.input_mode, 'slider');
    
    for i = 1:length(handles.plant_sliders)
        if i <= num_plant_params
            set(handles.plant_labels(i), 'String', plant_params(i).name);
            
            if is_slider_mode
                slider_step = 0.1 / (plant_params(i).max - plant_params(i).min);
                set(handles.plant_sliders(i), ...
                    'Min', plant_params(i).min, ...
                    'Max', plant_params(i).max, ...
                    'Value', plant_params(i).init, ...
                    'Tag', plant_params(i).label, ...
                    'SliderStep', [slider_step, slider_step]);
                set(handles.plant_value_texts(i), 'String', sprintf('%s = %.1f', plant_params(i).label, plant_params(i).init));
                set(handles.plant_labels(i), 'Visible', 'on');
                set(handles.plant_sliders(i), 'Visible', 'on');
                set(handles.plant_text_inputs(i), 'Visible', 'off');
                set(handles.plant_value_texts(i), 'Visible', 'on');
            else
                set(handles.plant_text_inputs(i), 'String', sprintf('%.6g', plant_params(i).init));
                set(handles.plant_value_texts(i), 'String', sprintf('%s = %.6g', plant_params(i).label, plant_params(i).init));
                set(handles.plant_labels(i), 'Visible', 'on');
                set(handles.plant_sliders(i), 'Visible', 'off');
                set(handles.plant_text_inputs(i), 'Visible', 'on');
                set(handles.plant_value_texts(i), 'Visible', 'on');
            end
        else
            set(handles.plant_labels(i), 'Visible', 'off');
            set(handles.plant_sliders(i), 'Visible', 'off');
            set(handles.plant_text_inputs(i), 'Visible', 'off');
            set(handles.plant_value_texts(i), 'Visible', 'off');
        end
    end
    
    % Update CONTROLLER parameters
    controller_params = getControllerParameters(fig);
    num_controller_params = length(controller_params);
    
    for i = 1:length(handles.controller_sliders)
        if i <= num_controller_params
            set(handles.controller_labels(i), 'String', controller_params(i).name);
            
            if is_slider_mode
                slider_step = 0.1 / (controller_params(i).max - controller_params(i).min);
                set(handles.controller_sliders(i), ...
                    'Min', controller_params(i).min, ...
                    'Max', controller_params(i).max, ...
                    'Value', controller_params(i).init, ...
                    'Tag', controller_params(i).label, ...
                    'SliderStep', [slider_step, slider_step]);
                set(handles.controller_value_texts(i), 'String', sprintf('%s = %.1f', controller_params(i).label, controller_params(i).init));
                set(handles.controller_labels(i), 'Visible', 'on');
                set(handles.controller_sliders(i), 'Visible', 'on');
                set(handles.controller_text_inputs(i), 'Visible', 'off');
                set(handles.controller_value_texts(i), 'Visible', 'on');
            else
                set(handles.controller_text_inputs(i), 'String', sprintf('%.6g', controller_params(i).init));
                set(handles.controller_value_texts(i), 'String', sprintf('%s = %.6g', controller_params(i).label, controller_params(i).init));
                set(handles.controller_labels(i), 'Visible', 'on');
                set(handles.controller_sliders(i), 'Visible', 'off');
                set(handles.controller_text_inputs(i), 'Visible', 'on');
                set(handles.controller_value_texts(i), 'Visible', 'on');
            end
        else
            set(handles.controller_labels(i), 'Visible', 'off');
            set(handles.controller_sliders(i), 'Visible', 'off');
            set(handles.controller_text_inputs(i), 'Visible', 'off');
            set(handles.controller_value_texts(i), 'Visible', 'off');
        end
    end
    
    % Show state-space note only for plant method 5
    if handles.current_method == 5
        set(handles.ss_note, 'Visible', 'on');
    else
        set(handles.ss_note, 'Visible', 'off');
    end
    
    drawnow();
end

function updateControllerUIControls(fig)
    % Update only controller parameter controls without resetting plant parameters
    if nargin < 1
        fig = gcf;
    end
    handles = get(fig, 'UserData');
    
    if isempty(handles)
        return;
    end
    
    % Update CONTROLLER parameters only
    controller_params = getControllerParameters(fig);
    num_controller_params = length(controller_params);
    is_slider_mode = strcmp(handles.input_mode, 'slider');
    
    for i = 1:length(handles.controller_sliders)
        if i <= num_controller_params
            set(handles.controller_labels(i), 'String', controller_params(i).name);
            
            if is_slider_mode
                slider_step = 0.1 / (controller_params(i).max - controller_params(i).min);
                set(handles.controller_sliders(i), ...
                    'Min', controller_params(i).min, ...
                    'Max', controller_params(i).max, ...
                    'Value', controller_params(i).init, ...
                    'Tag', controller_params(i).label, ...
                    'SliderStep', [slider_step, slider_step]);
                set(handles.controller_value_texts(i), 'String', sprintf('%s = %.1f', controller_params(i).label, controller_params(i).init));
                set(handles.controller_labels(i), 'Visible', 'on');
                set(handles.controller_sliders(i), 'Visible', 'on');
                set(handles.controller_text_inputs(i), 'Visible', 'off');
                set(handles.controller_value_texts(i), 'Visible', 'on');
            else
                set(handles.controller_text_inputs(i), 'String', sprintf('%.6g', controller_params(i).init));
                set(handles.controller_value_texts(i), 'String', sprintf('%s = %.6g', controller_params(i).label, controller_params(i).init));
                set(handles.controller_labels(i), 'Visible', 'on');
                set(handles.controller_sliders(i), 'Visible', 'off');
                set(handles.controller_text_inputs(i), 'Visible', 'on');
                set(handles.controller_value_texts(i), 'Visible', 'on');
            end
        else
            set(handles.controller_labels(i), 'Visible', 'off');
            set(handles.controller_sliders(i), 'Visible', 'off');
            set(handles.controller_text_inputs(i), 'Visible', 'off');
            set(handles.controller_value_texts(i), 'Visible', 'off');
        end
    end
    
    drawnow();
end

function plantSliderCallback(src, event)
    fig = gcbf;
    handles = get(fig, 'UserData');
    params = getPlantParameters(fig);
    
    for i = 1:length(handles.plant_sliders)
        if strcmp(get(handles.plant_sliders(i), 'Visible'), 'on')
            raw_value = get(handles.plant_sliders(i), 'Value');
            rounded_value = round(raw_value * 10) / 10;
            set(handles.plant_sliders(i), 'Value', rounded_value);
            param_idx = min(i, length(params));
            set(handles.plant_value_texts(i), 'String', sprintf('%s = %.1f', params(param_idx).label, rounded_value));
        end
    end
    
    updatePlots(fig);
end

function plantValueEditCallback(src, event)
    fig = gcbf;
    handles = get(fig, 'UserData');
    params = getPlantParameters(fig);
    
    idx = find(handles.plant_text_inputs == src);
    if isempty(idx)
        return;
    end
    
    str = get(src, 'String');
    val = str2double(str);
    
    if isnan(val)
        val = params(idx).init;
    end
    
    set(src, 'String', sprintf('%.6g', val));
    set(handles.plant_value_texts(idx), 'String', sprintf('%s = %.6g', params(idx).label, val));
    
    updatePlots(fig);
end

function controllerSliderCallback(src, event)
    fig = gcbf;
    handles = get(fig, 'UserData');
    params = getControllerParameters(fig);
    
    for i = 1:length(handles.controller_sliders)
        if strcmp(get(handles.controller_sliders(i), 'Visible'), 'on')
            raw_value = get(handles.controller_sliders(i), 'Value');
            rounded_value = round(raw_value * 10) / 10;
            set(handles.controller_sliders(i), 'Value', rounded_value);
            param_idx = min(i, length(params));
            set(handles.controller_value_texts(i), 'String', sprintf('%s = %.1f', params(param_idx).label, rounded_value));
        end
    end
    
    updatePlots(fig);
end

function controllerValueEditCallback(src, event)
    fig = gcbf;
    handles = get(fig, 'UserData');
    params = getControllerParameters(fig);
    
    idx = find(handles.controller_text_inputs == src);
    if isempty(idx)
        return;
    end
    
    str = get(src, 'String');
    val = str2double(str);
    
    if isnan(val)
        val = params(idx).init;
    end
    
    set(src, 'String', sprintf('%.6g', val));
    set(handles.controller_value_texts(idx), 'String', sprintf('%s = %.6g', params(idx).label, val));
    
    updatePlots(fig);
end

function resetCallback(src, event)
    fig = gcbf;
    handles = get(fig, 'UserData');
    
    updateUIControls(fig);
    updatePlots(fig);
end

function exportCallback(src, event)
    fig = gcbf;
    handles = get(fig, 'UserData');
    
    % Get plant and controller values
    [plant_values, controller_values] = getAllValues(fig);
    
    % Get system characteristics
    [num_plant, den_plant, wn, zeta, K] = convertToTransferFunction(plant_values, handles.current_method);
    [num_cl, den_cl] = computeClosedLoop(num_plant, den_plant, controller_values, handles.controller_type, plant_values, handles.current_method);
    poles_cl = roots(den_cl);
    zeros_cl = roots(num_cl);
    
    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    filename = sprintf('system_response_%s.txt', timestamp);
    
    controller_names = {'None', 'PID Controller', 'State Feedback'};
    controller_name = controller_names{handles.controller_type};
    plant_methods = {'First-Order Lag', 'Standard 2nd-Order', 'ODE Coefficients', 'Rational', 'State-Space'};
    plant_method_name = plant_methods{handles.current_method};
    
    fid = fopen(filename, 'w');
    fprintf(fid, '========================================\n');
    fprintf(fid, '  System Response Analysis Export\n');
    fprintf(fid, '========================================\n');
    fprintf(fid, 'Generated: %s\n\n', datestr(now));
    
    % System Configuration
    fprintf(fid, 'SYSTEM CONFIGURATION\n');
    fprintf(fid, '--------------------\n');
    fprintf(fid, 'Plant Model: %s\n', plant_method_name);
    fprintf(fid, 'Controller: %s\n', controller_name);
    fprintf(fid, 'Input Mode: %s\n\n', handles.input_mode);
    
    % Plant Parameters
    fprintf(fid, 'PLANT PARAMETERS\n');
    fprintf(fid, '----------------\n');
    plant_params = getPlantParameters(fig);
    for i = 1:length(plant_values)
        fprintf(fid, '%s = %.6g\n', plant_params(i).label, plant_values(i));
    end
    fprintf(fid, '\n');
    
    % Plant Characteristics
    fprintf(fid, 'PLANT CHARACTERISTICS\n');
    fprintf(fid, '---------------------\n');
    fprintf(fid, 'Natural Frequency (ωn): %.4f rad/s\n', wn);
    fprintf(fid, 'Damping Ratio (ζ): %.4f\n', zeta);
    fprintf(fid, 'DC Gain (K): %.4f\n', K);
    fprintf(fid, 'Plant Transfer Function:\n');
    fprintf(fid, '  Numerator: [%s]\n', sprintf('%.4g ', num_plant));
    fprintf(fid, '  Denominator: [%s]\n\n', sprintf('%.4g ', den_plant));
    
    % Controller Parameters
    if handles.controller_type > 1
        fprintf(fid, 'CONTROLLER PARAMETERS\n');
        fprintf(fid, '---------------------\n');
        controller_params = getControllerParameters(fig);
        for i = 1:length(controller_values)
            fprintf(fid, '%s = %.6g\n', controller_params(i).label, controller_values(i));
        end
        fprintf(fid, '\n');
    end
    
    % Closed-Loop Characteristics
    fprintf(fid, 'CLOSED-LOOP CHARACTERISTICS\n');
    fprintf(fid, '----------------------------\n');
    
    % Stability
    is_stable = all(real(poles_cl) < -1e-6);
    fprintf(fid, 'Stability: %s\n', ternary(is_stable, 'STABLE', 'UNSTABLE'));
    
    % Poles and zeros
    fprintf(fid, 'Closed-Loop Poles:\n');
    for i = 1:length(poles_cl)
        if abs(imag(poles_cl(i))) > 1e-6
            fprintf(fid, '  p%d = %.6f ± j%.6f\n', i, real(poles_cl(i)), abs(imag(poles_cl(i))));
        else
            fprintf(fid, '  p%d = %.6f\n', i, real(poles_cl(i)));
        end
    end
    fprintf(fid, 'Closed-Loop Zeros:\n');
    if isempty(zeros_cl)
        fprintf(fid, '  (none)\n');
    else
        for i = 1:length(zeros_cl)
            if abs(imag(zeros_cl(i))) > 1e-6
                fprintf(fid, '  z%d = %.6f ± j%.6f\n', i, real(zeros_cl(i)), abs(imag(zeros_cl(i))));
            else
                fprintf(fid, '  z%d = %.6f\n', i, real(zeros_cl(i)));
            end
        end
    end
    
    % Calculate closed-loop damping and performance
    cl_wn = NaN; cl_zeta = NaN; overshoot = NaN; settling = NaN;
    if length(poles_cl) >= 1
        cl_wn = abs(poles_cl(1));
        if abs(imag(poles_cl(1))) > 1e-6
            cl_zeta = max(0, -real(poles_cl(1)) / abs(poles_cl(1)));
        else
            cl_zeta = 1.0;
        end
        if cl_zeta > 0 && cl_zeta < 1
            overshoot = exp(-cl_zeta*pi/sqrt(1-cl_zeta^2)) * 100;
            if cl_zeta*cl_wn > 0
                settling = 4 / (cl_zeta * cl_wn);
            end
        elseif cl_zeta >= 1 && cl_wn > 0
            settling = 4 / (cl_zeta * cl_wn);
            overshoot = 0;
        end
    end
    fprintf(fid, 'CL Natural Frequency: %.4f rad/s\n', cl_wn);
    fprintf(fid, 'CL Damping Ratio: %.4f\n', cl_zeta);
    if ~isnan(overshoot)
        fprintf(fid, 'Est. Overshoot: %.2f %%\n', overshoot);
    end
    if ~isnan(settling)
        fprintf(fid, 'Est. Settling Time (4%%): %.3f s\n', settling);
    end
    
    fprintf(fid, '\nClosed-Loop Transfer Function:\n');
    fprintf(fid, '  Numerator: [%s]\n', sprintf('%.4g ', num_cl));
    fprintf(fid, '  Denominator: [%s]\n\n', sprintf('%.4g ', den_cl));
    
    % Frequency Domain Characteristics
    fprintf(fid, 'FREQUENCY DOMAIN CHARACTERISTICS\n');
    fprintf(fid, '--------------------------------\n');
    omega_range = logspace(-2, 2, 300);
    [mag_db, phase_deg] = computeBode(num_cl, den_cl, omega_range);
    
    % Find -3dB crossover
    idx_3db = find(mag_db <= -3, 1, 'first');
    if ~isempty(idx_3db) && idx_3db > 1
        omega_3db = interp1(mag_db(idx_3db-1:idx_3db), omega_range(idx_3db-1:idx_3db), -3);
        fprintf(fid, '-3dB Bandwidth: %.4f rad/s (%.4f Hz)\n', omega_3db, omega_3db/(2*pi));
    else
        fprintf(fid, '-3dB Bandwidth: N/A\n');
    end
    
    % Find phase crossovers
    idx_45 = find(phase_deg <= -45, 1, 'first');
    idx_90 = find(phase_deg <= -90, 1, 'first');
    idx_135 = find(phase_deg <= -135, 1, 'first');
    
    if ~isempty(idx_45) && idx_45 > 1
        omega_45 = interp1(phase_deg(idx_45-1:idx_45), omega_range(idx_45-1:idx_45), -45);
        fprintf(fid, '-45° Phase Crossover: %.4f rad/s (%.4f Hz)\n', omega_45, omega_45/(2*pi));
    else
        fprintf(fid, '-45° Phase Crossover: N/A\n');
    end
    
    if ~isempty(idx_90) && idx_90 > 1
        omega_90 = interp1(phase_deg(idx_90-1:idx_90), omega_range(idx_90-1:idx_90), -90);
        fprintf(fid, '-90° Phase Crossover: %.4f rad/s (%.4f Hz)\n', omega_90, omega_90/(2*pi));
    else
        fprintf(fid, '-90° Phase Crossover: N/A\n');
    end
    
    if ~isempty(idx_135) && idx_135 > 1
        omega_135 = interp1(phase_deg(idx_135-1:idx_135), omega_range(idx_135-1:idx_135), -135);
        fprintf(fid, '-135° Phase Crossover: %.4f rad/s (%.4f Hz)\n', omega_135, omega_135/(2*pi));
    else
        fprintf(fid, '-135° Phase Crossover: N/A\n');
    end
    fprintf(fid, '\n');
    
    % System Performance Notes
    fprintf(fid, 'PERFORMANCE NOTES\n');
    fprintf(fid, '-----------------\n');
    if is_stable
        fprintf(fid, '✓ System is stable\n');
        if length(poles_cl) >= 2 && abs(imag(poles_cl(1))) > 1e-6
            if cl_zeta < 0.3
                fprintf(fid, '⚠ Lightly damped - may have overshoot\n');
            elseif cl_zeta > 1.0
                fprintf(fid, '⚠ Overdamped - slow response\n');
            else
                fprintf(fid, '✓ Well-damped system\n');
            end
        end
    else
        fprintf(fid, '✗ WARNING: System is UNSTABLE\n');
    end
    
    fprintf(fid, '\n========================================\n');
    
    fclose(fid);
    
    % Temporarily expand plots for export
    axes_handles = handles.axes;
    old_positions = cell(size(axes_handles));
    for k = 1:length(axes_handles)
        old_positions{k} = get(axes_handles(k), 'Position');
    end
    new_positions = [ ...
        0.04 0.55 0.44 0.40; ...
        0.54 0.55 0.44 0.40; ...
        0.04 0.07 0.44 0.40; ...
        0.54 0.07 0.44 0.40 ...
    ];
    for k = 1:min(length(axes_handles), size(new_positions, 1))
        set(axes_handles(k), 'Position', new_positions(k, :));
    end
    
    img_filename = sprintf('system_response_%s.png', timestamp);
    print(handles.fig, img_filename, '-dpng', '-r150');
    
    % Restore positions
    for k = 1:length(axes_handles)
        set(axes_handles(k), 'Position', old_positions{k});
    end
    
    fprintf('\n===== EXPORT COMPLETE =====\n');
    fprintf('Full analysis saved to: %s\n', filename);
    fprintf('Figure saved to: %s\n\n', img_filename);
end

%% =========================================================================
% PLOTTING FUNCTIONS
% =========================================================================

function updatePlots(fig)
    try
    if nargin < 1
        fig = gcf;
    end
    handles = get(fig, 'UserData');
    
    if isempty(handles) || ~isfield(handles, 'axes')
        fprintf('Handles not properly initialized\n');
        return;
    end
    
    % Get plant and controller values
    [plant_values, controller_values] = getAllValues(fig);
    
    % Convert plant to transfer function
    [num_plant, den_plant, wn, zeta, K] = convertToTransferFunction(plant_values, handles.current_method);
    
    % Compute closed-loop system
    [num_cl, den_cl] = computeClosedLoop(num_plant, den_plant, controller_values, handles.controller_type, plant_values, handles.current_method);
    
    % Get axes
    ax1 = handles.axes(1);
    ax2 = handles.axes(2);
    ax3_mag = handles.axes(3);
    ax3_phase = handles.axes(4);
    
    % Extract closed-loop parameters for plotting
    [wn_cl, zeta_cl, K_cl] = extractSystemParams(num_cl, den_cl);
    
    % Time vector
    poles_cl = roots(den_cl);
    max_real = max(real(poles_cl));
    if max_real < 0 && ~isnan(max_real)
        T_settle = max(4 / abs(max_real), 1);
    else
        T_settle = 10;
    end
    t = linspace(0, T_settle * 4, 1000);
    
    % Plot 1: Step Response (closed-loop)
    cla(ax1);
    y_step = computeStepResponse(num_cl, den_cl, wn_cl, zeta_cl, K_cl, t);
    plot(ax1, t, y_step, 'b-', 'LineWidth', 2.5);
    grid(ax1, 'on');
    xlabel(ax1, 'Time (s)', 'FontSize', 11);
    ylabel(ax1, 'Output', 'FontSize', 11);
    if handles.controller_type == 1
        title(ax1, 'Step Response (Open Loop)', 'FontSize', 14, 'FontWeight', 'bold');
    else
        title(ax1, 'Step Response (Closed Loop)', 'FontSize', 14, 'FontWeight', 'bold');
    end
    set(ax1, 'FontSize', 10);
    
    % Plot 2: Impulse Response (closed-loop)
    cla(ax2);
    y_impulse = computeImpulseResponse(num_cl, den_cl, wn_cl, zeta_cl, K_cl, t);
    plot(ax2, t, y_impulse, 'b-', 'LineWidth', 2.5);
    grid(ax2, 'on');
    xlabel(ax2, 'Time (s)', 'FontSize', 11);
    ylabel(ax2, 'Output', 'FontSize', 11);
    if handles.controller_type == 1
        title(ax2, 'Impulse Response (Open Loop)', 'FontSize', 14, 'FontWeight', 'bold');
    else
        title(ax2, 'Impulse Response (Closed Loop)', 'FontSize', 14, 'FontWeight', 'bold');
    end
    set(ax2, 'FontSize', 10);
    
    % Plot 3: Bode Magnitude
    cla(ax3_mag);
    omega = logspace(-2, 2, 300);
    [mag_db, phase_deg] = computeBode(num_cl, den_cl, omega);
    
    semilogx(ax3_mag, omega, mag_db, 'b-', 'LineWidth', 2.5);
    grid(ax3_mag, 'on');
    xlabel(ax3_mag, 'Frequency (rad/s)', 'FontSize', 11);
    ylabel(ax3_mag, 'Magnitude (dB)', 'FontSize', 11);
    title(ax3_mag, 'Bode Magnitude', 'FontSize', 14, 'FontWeight', 'bold');
    set(ax3_mag, 'FontSize', 10);
    % Find -3dB crossover frequency and add vertical cursor
    hold(ax3_mag, 'on');
    idx_3db = find(mag_db <= -3, 1, 'first');
    if ~isempty(idx_3db) && idx_3db > 1
        omega_3db = interp1(mag_db(idx_3db-1:idx_3db), omega(idx_3db-1:idx_3db), -3);
        ylims = ylim(ax3_mag);
        plot(ax3_mag, [omega_3db omega_3db], ylims, 'r--', 'LineWidth', 1.5);
        plot(ax3_mag, omega_3db, -3, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        text(ax3_mag, omega_3db*1.15, -3, sprintf('-3dB: %.2f rad/s', omega_3db), 'FontSize', 9, 'Color', 'r');
    end
    hold(ax3_mag, 'off');
    
    % Plot 4: Bode Phase
    cla(ax3_phase);
    semilogx(ax3_phase, omega, phase_deg, 'b-', 'LineWidth', 2.5);
    grid(ax3_phase, 'on');
    xlabel(ax3_phase, 'Frequency (rad/s)', 'FontSize', 11);
    ylabel(ax3_phase, 'Phase (degrees)', 'FontSize', 11);
    title(ax3_phase, 'Bode Phase', 'FontSize', 14, 'FontWeight', 'bold');
    set(ax3_phase, 'FontSize', 10);
    % Set y-ticks to 45-degree increments
    yticks(ax3_phase, -180:45:0);
    % Find crossover frequencies and add vertical cursors
    hold(ax3_phase, 'on');
    ylims = ylim(ax3_phase);
    idx_45 = find(phase_deg <= -45, 1, 'first');
    idx_90 = find(phase_deg <= -90, 1, 'first');
    idx_135 = find(phase_deg <= -135, 1, 'first');
    if ~isempty(idx_45) && idx_45 > 1
        omega_45 = interp1(phase_deg(idx_45-1:idx_45), omega(idx_45-1:idx_45), -45);
        plot(ax3_phase, [omega_45 omega_45], ylims, 'r--', 'LineWidth', 1.2);
        plot(ax3_phase, omega_45, -45, 'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
        text(ax3_phase, omega_45*1.15, -45, sprintf('-45°: %.2f rad/s', omega_45), 'FontSize', 9, 'Color', 'r');
    end
    if ~isempty(idx_90) && idx_90 > 1
        omega_90 = interp1(phase_deg(idx_90-1:idx_90), omega(idx_90-1:idx_90), -90);
        plot(ax3_phase, [omega_90 omega_90], ylims, 'r--', 'LineWidth', 1.2);
        plot(ax3_phase, omega_90, -90, 'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
        text(ax3_phase, omega_90*1.15, -90, sprintf('-90°: %.2f rad/s', omega_90), 'FontSize', 9, 'Color', 'r');
    end
    if ~isempty(idx_135) && idx_135 > 1
        omega_135 = interp1(phase_deg(idx_135-1:idx_135), omega(idx_135-1:idx_135), -135);
        plot(ax3_phase, [omega_135 omega_135], ylims, 'r--', 'LineWidth', 1.2);
        plot(ax3_phase, omega_135, -135, 'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
        text(ax3_phase, omega_135*1.15, -135, sprintf('-135°: %.2f rad/s', omega_135), 'FontSize', 9, 'Color', 'r');
    end
    hold(ax3_phase, 'off');
    
    % Update info panel
    updateInfo(fig, plant_values, controller_values, wn, zeta, K, poles_cl);
    
    drawnow();
    
    catch err
        fprintf('ERROR in updatePlots: %s\n', err.message);
        if isfield(err, 'stack')
            for i = 1:length(err.stack)
                fprintf('  Line %d\n', err.stack(i).line);
            end
        end
    end
end

function updateInfo(fig, plant_values, controller_values, wn, zeta, K, poles_cl)
    handles = get(fig, 'UserData');
    info_text = handles.info_text;
    
    % Determine stability
    is_stable = all(real(poles_cl) < -1e-6);
    stability_str = ternary(is_stable, 'Stable ✓', 'UNSTABLE ✗');
    
    % Calculate closed-loop damping ratio and metrics from dominant pole
    cl_wn = abs(poles_cl(1));
    if abs(imag(poles_cl(1))) > 1e-6
        cl_zeta = max(0, -real(poles_cl(1)) / abs(poles_cl(1)));
    else
        cl_zeta = 1.0;
    end
    overshoot = 0;
    settling = NaN;
    if cl_zeta > 0 && cl_zeta < 1
        overshoot = exp(-cl_zeta*pi/sqrt(1-cl_zeta^2)) * 100;
        if cl_zeta*cl_wn > 0
            settling = 4 / (cl_zeta * cl_wn);
        end
    elseif cl_zeta >= 1 && cl_wn > 0
        settling = 4 / (cl_zeta * cl_wn);
    end
    
    % Build compact info string
    info_str = sprintf('%s\n', stability_str);
    info_str = sprintf('%sCL: ωn=%.1f, ζ=%.2f\n', info_str, cl_wn, cl_zeta);
    
    if handles.controller_type == 2  % PID
        info_str = sprintf('%sKp=%.2f Ki=%.2f Kd=%.2f\n', info_str, ...
            controller_values(1), controller_values(2), controller_values(3));
    elseif handles.controller_type == 3  % State feedback
        info_str = sprintf('%sK₁=%.2f K₂=%.2f\n', info_str, ...
            controller_values(1), controller_values(2));
    else
        info_str = sprintf('%sOpen Loop\n', info_str);
    end
    
    % Add poles compactly
    if ~isempty(poles_cl) && length(poles_cl) >= 2
        if abs(imag(poles_cl(1))) > 1e-6
            info_str = sprintf('%sP: %.2f±j%.2f', info_str, real(poles_cl(1)), abs(imag(poles_cl(1))));
        else
            info_str = sprintf('%sP: %.3f, %.3f', info_str, poles_cl(1), poles_cl(2));
        end
    end
    
    % Add concise performance metrics
    if ~isnan(settling)
        info_str = sprintf('%s\nOS=%.0f%% Ts=%.2fs', info_str, overshoot, settling);
    end
    
    set(info_text, 'String', info_str);
end

function result = ternary(condition, true_val, false_val)
    % Simple ternary operator
    if condition
        result = true_val;
    else
        result = false_val;
    end
end

%% =========================================================================
% HELPER FUNCTIONS
% =========================================================================

function params = getPlantParameters(fig)
    handles = get(fig, 'UserData');
    
    switch handles.current_method
        case 1
            params = handles.params_method1;
        case 2
            params = handles.params_method2;
        case 3
            params = handles.params_method3;
        case 4
            params = handles.params_method4;
        case 5
            params = handles.params_method5;
    end
end

function params = getControllerParameters(fig)
    handles = get(fig, 'UserData');
    
    if handles.controller_type == 2  % PID
        params = handles.params_pid;
    elseif handles.controller_type == 3  % State feedback
        params = handles.params_statefb;
    else
        params = struct([]);  % Empty
    end
end

function [plant_values, controller_values] = getAllValues(fig)
    handles = get(fig, 'UserData');
    
    % Get plant parameter defaults
    plant_params = getPlantParameters(fig);
    plant_values = zeros(1, length(plant_params));
    for i = 1:length(plant_params)
        plant_values(i) = plant_params(i).init;
    end
    
    % Get controller parameter defaults
    controller_params = getControllerParameters(fig);
    if ~isempty(controller_params)
        controller_values = zeros(1, length(controller_params));
        for i = 1:length(controller_params)
            controller_values(i) = controller_params(i).init;
        end
    else
        controller_values = [];
    end
    
    % Get actual current plant values from controls
    is_slider_mode = strcmp(handles.input_mode, 'slider');
    
    for i = 1:length(handles.plant_sliders)
        if strcmp(get(handles.plant_labels(i), 'Visible'), 'on') && i <= length(plant_values)
            if is_slider_mode
                plant_values(i) = get(handles.plant_sliders(i), 'Value');
            else
                str = get(handles.plant_text_inputs(i), 'String');
                val = str2double(str);
                if ~isnan(val)
                    plant_values(i) = val;
                end
            end
        end
    end
    
    % Get actual current controller values from controls
    if ~isempty(controller_values)
        for i = 1:length(handles.controller_sliders)
            if strcmp(get(handles.controller_labels(i), 'Visible'), 'on') && i <= length(controller_values)
                if is_slider_mode
                    controller_values(i) = get(handles.controller_sliders(i), 'Value');
                else
                    str = get(handles.controller_text_inputs(i), 'String');
                    val = str2double(str);
                    if ~isnan(val)
                        controller_values(i) = val;
                    end
                end
            end
        end
    end
end

function [num_cl, den_cl] = computeClosedLoop(num_plant, den_plant, controller_values, controller_type, plant_values, current_method)
    % Compute closed-loop transfer function based on controller type
    
    if controller_type == 1  % No controller
        num_cl = num_plant;
        den_cl = den_plant;
    elseif controller_type == 2  % PID
        Kp = controller_values(1);
        Ki = controller_values(2);
        Kd = controller_values(3);
        
        % C(s) = Kp + Ki/s + Kd*s = (Kd*s^2 + Kp*s + Ki) / s
        num_c = [Kd, Kp, Ki];
        den_c = [1, 0];
        
        % Series: G_ol(s) = C(s)*G(s)
        num_ol = conv(num_c, num_plant);
        den_ol = conv(den_c, den_plant);
        
        % Closed-loop with unity feedback: G_cl = G_ol / (1 + G_ol)
        num_cl = num_ol;
        den_cl = polyadd(den_ol, num_ol);
    elseif controller_type == 3  % State feedback
        % If plant method 5 (state-space), compute true closed-loop TF using A,B,C,D
        if current_method == 5 && length(plant_values) >= 4
            % values = [A11, A12, A21, A22]; B=[0;1], C=[1 0], D=0
            A11 = plant_values(1); A12 = plant_values(2);
            A21 = plant_values(3); A22 = plant_values(4);
            A = [A11, A12; A21, A22];
            B = [0; 1];
            C = [1, 0];
            D = 0;
            Kfb = [controller_values(1), controller_values(2)];
            A_cl = A - B * Kfb;  % A-BK
            % For reference input r: xdot = (A-BK)x + Br, y = Cx
            % Transfer function: Y/R = C*(sI-(A-BK))^-1*B
            % Denominator from characteristic polynomial of A_cl
            den_cl = [1, -(A_cl(1,1)+A_cl(2,2)), det(A_cl)];
            % Numerator: need C*adj(sI-A_cl)*B where adj(sI-A) for 2x2 = [s-a22, a12; a21, s-a11]
            % C*adj(sI-A_cl)*B = [1 0]*[s-A_cl(2,2), A_cl(1,2); A_cl(2,1), s-A_cl(1,1)]*[0;1]
            %                  = [s-A_cl(2,2), A_cl(1,2)]*[0;1] = A_cl(1,2)
            num_cl = [0, 0, A_cl(1,2)];
            if abs(A_cl(1,2)) < 1e-12
                % If numerator is near zero, system may not be controllable/observable
                num_cl = [0, 0, 1e-6];  % avoid complete zero
            end
        else
            % fallback to simplified output feedback using K_eff = K1+K2
            K_eff = sum(controller_values);
            num_ol = K_eff * num_plant;
            den_ol = den_plant;
            num_cl = num_ol;
            den_cl = polyadd(den_ol, num_ol);
        end
    else
        num_cl = num_plant;
        den_cl = den_plant;
    end
end

function c = polyadd(a, b)
    % Add two polynomials (pad with zeros if needed)
    if length(a) > length(b)
        b = [zeros(1, length(a) - length(b)), b];
    elseif length(b) > length(a)
        a = [zeros(1, length(b) - length(a)), a];
    end
    c = a + b;
end

function [num, den, wn, zeta, K] = convertToTransferFunction(values, method)
    % Same as before - convert plant model to transfer function
    switch method
        case 1  % Time Constant
            tau = values(1);
            K = values(2);
            wn = 1 / tau;
            zeta = 1.0;
            wn2 = wn^2;
            num = [0, 0, K * wn2];
            den = [1, 2*zeta*wn, wn2];
            
        case 2  % Natural Frequency & Damping
            wn = values(1);
            zeta = max(values(2), 0.001);
            K = values(3);
            wn2 = wn^2;
            num = [0, 0, K * wn2];
            den = [1, 2*zeta*wn, wn2];
            
        case 3  % ODE Coefficients
            a2 = values(1);
            a1 = values(2);
            a0 = values(3);
            b = values(4);
            num = [0, 0, b];
            den = [a2, a1, a0];
            wn2 = a0 / a2;
            wn = sqrt(wn2);
            zeta = a1 / (2 * sqrt(a2 * a0));
            K = b / a0;
            
        case 4  % Laplace Transfer Function
            b0 = values(1);
            a2 = values(2);
            a1 = values(3);
            a0 = values(4);
            num = [0, 0, b0];
            den = [a2, a1, a0];
            wn2 = a0 / a2;
            wn = sqrt(wn2);
            zeta = a1 / (2 * sqrt(a2 * a0));
            K = b0 / a0;
            
        case 5  % State Space
            if length(values) < 4
                error('Method 5 requires 4 values, got %d', length(values));
            end
            A = [values(1), values(2); values(3), values(4)];
            traceA = A(1,1) + A(2,2);
            detA = A(1,1)*A(2,2) - A(1,2)*A(2,1);
            den_vec = [1, -traceA, detA];
            num_const = A(1,2);
            den = [1, -traceA/den_vec(1), detA/den_vec(1)];
            num = [0, 0, num_const/den_vec(1)];
            a1 = den(2);
            a0 = den(3);
            wn2 = a0;
            wn = sqrt(abs(wn2));
            if wn2 > 0 && a1 > 0
                zeta = a1 / (2 * sqrt(wn2));
            else
                zeta = 0.7;
            end
            if wn2 > 0
                K = num_const / wn2;
            else
                K = 1;
            end
    end
end

function values = convertFromTransferFunction(wn, zeta, K, method)
    % Same as before - convert from standard form to method parameters
    switch method
        case 1
            tau = 1 / wn;
            values = [tau, K];
        case 2
            values = [wn, zeta, K];
        case 3
            wn2 = wn^2;
            a2 = 1;
            a1 = 2*zeta*wn;
            a0 = wn2;
            b = K*wn2;
            values = [a2, a1, a0, b];
        case 4
            wn2 = wn^2;
            b0 = K*wn2;
            a2 = 1;
            a1 = 2*zeta*wn;
            a0 = wn2;
            values = [b0, a2, a1, a0];
        case 5
            wn2 = wn^2;
            A11 = 0;
            A12 = K * wn2;
            A21 = -1;
            A22 = -2*zeta*wn;
            values = [A11, A12, A21, A22];
    end
end

function [wn, zeta, K] = extractSystemParams(num, den)
    % Extract natural frequency, damping, and DC gain from 2nd order system
    % Assumes den = [a2, a1, a0] form
    
    if length(den) < 3
        % First order or simpler
        wn = 1;
        zeta = 1;
        K = sum(num) / sum(den);
        return;
    end
    
    % Normalize denominator
    a2 = den(1);
    a1 = den(2);
    a0 = den(3);
    
    if abs(a2) < eps
        wn = 1;
        zeta = 1;
        K = sum(num) / sum(den);
        return;
    end
    
    % Extract parameters
    wn2 = a0 / a2;
    wn = sqrt(abs(wn2));
    
    if wn > eps
        zeta = a1 / (2 * a2 * wn);
    else
        zeta = 1;
        wn = 1;
    end
    
    % DC gain
    K = sum(num) / sum(den);
end

function y = computeStepResponse(num, den, wn, zeta, K, t)
    % Compute step response for 2nd order system analytically
    
    if abs(zeta) < eps
        zeta = 0.001;  % Avoid singularity
    end
    
    if zeta < 1  % Underdamped
        wd = wn * sqrt(1 - zeta^2);
        y = K * (1 - exp(-zeta*wn*t) .* (cos(wd*t) + (zeta/sqrt(1-zeta^2))*sin(wd*t)));
    elseif abs(zeta - 1) < 0.01  % Critically damped
        y = K * (1 - exp(-wn*t) .* (1 + wn*t));
    else  % Overdamped
        s1 = -zeta*wn + wn*sqrt(zeta^2 - 1);
        s2 = -zeta*wn - wn*sqrt(zeta^2 - 1);
        if abs(s1 - s2) > eps
            y = K * (1 + (s2*exp(s1*t) - s1*exp(s2*t)) / (s1 - s2));
        else
            y = K * (1 - exp(-wn*t) .* (1 + wn*t));
        end
    end
    
    % Clamp extreme values
    y(y > 1e6) = 1e6;
    y(y < -1e6) = -1e6;
end

function y = computeImpulseResponse(num, den, wn, zeta, K, t)
    % Compute impulse response for 2nd order system analytically
    
    if abs(zeta) < eps
        zeta = 0.001;
    end
    
    wn2 = wn^2;
    
    if zeta < 1  % Underdamped
        wd = wn * sqrt(1 - zeta^2);
        y = K * wn * exp(-zeta*wn*t) .* sin(wd*t) / sqrt(1-zeta^2);
    elseif abs(zeta - 1) < 0.01  % Critically damped
        y = K * wn2 * t .* exp(-wn*t);
    else  % Overdamped
        s1 = -zeta*wn + wn*sqrt(zeta^2 - 1);
        s2 = -zeta*wn - wn*sqrt(zeta^2 - 1);
        if abs(s1 - s2) > eps
            y = K * wn2 * (exp(s1*t) - exp(s2*t)) / (s1 - s2);
        else
            y = K * wn2 * t .* exp(-wn*t);
        end
    end
    
    % Clamp extreme values
    y(y > 1e6) = 1e6;
    y(y < -1e6) = -1e6;
end

function [mag_db, phase_deg] = computeBode(num, den, omega)
    % Compute Bode plot magnitude and phase
    
    s = 1j * omega;
    H = polyval(num, s) ./ polyval(den, s);
    
    mag = abs(H);
    mag_db = 20 * log10(mag + eps);
    phase_deg = angle(H) * 180 / pi;
    
    % Clamp extreme values
    mag_db(mag_db > 100) = 100;
    mag_db(mag_db < -200) = -200;
end

function sys = tf(num, den)
    % Simple transfer function representation
    sys = struct('num', num, 'den', den);
end

function [y, t] = step(sys, t)
    % Placeholder - not used anymore
    y = zeros(size(t));
end

function [y, t] = impulse(sys, t)
    % Placeholder - not used anymore
    y = zeros(size(t));
end

function [mag, phase, w] = bode(sys, w)
    % Placeholder - not used anymore
    mag = ones(size(w));
    phase = zeros(size(w));
end

function [bd, ad] = bilinear(b, a, fs)
    % Placeholder - not used anymore
    bd = b;
    ad = a;
end
