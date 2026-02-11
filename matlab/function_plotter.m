function function_plotter()
%% =========================================================================
% Function Plotter GUI (Polynomial: 12 terms a0-a11, Fourier: 9 terms a1-a9, b1-b9)
% MATLAB / Octave compatible with UK English labelling.
% Plots time-domain only; polynomial input also reports Fourier coefficients
% over the selected window (periodic extension).
% =========================================================================

close all; clc;

max_poly_terms = 11;   % a0 to a11 (12 coefficients) for polynomial
max_fourier_terms = 9; % a1-a9, b1-b9 for Fourier
max_terms = max_poly_terms; % For general use, default to polynomial

defaults.method = 1;          % 1 = polynomial, 2 = Fourier
defaults.input_mode = 'text'; % 'text' or 'slider'
defaults.dc = 0;              % DC offset for Fourier mode
defaults.f0 = 1;              % base frequency for Fourier mode (Hz)
defaults.coeffs = [0 0 0 0 0 0 0 0 1 0 0 0];  % a11 a10 ... a1 a0
defaults.amps_a = [0, 0, 0, 0, 0, 0, 0, 0, 0];  % a1 to a9 (cosine)
defaults.amps_b = [1, 0, 0, 0, 0, 0, 0, 0, 0];  % b1 to b9 (sine)
defaults.t_start = -1/defaults.f0;  % start time based on f0
defaults.t_end = 1/defaults.f0;     % end time based on f0
defaults.dt = 0.01;           % seconds
defaults.times_user_set = false;    % track if user manually set times

state = defaults;

fig = figure('Name', 'Function Plotter', 'NumberTitle', 'off');
set(fig, 'Position', [60, 60, 1400, 900]);
set(fig, 'Color', [0.94 0.94 0.94]);

panel_width = 260;
ax = axes('Parent', fig, 'Position', [0.30, 0.12, 0.65, 0.80]);

ui.panel = uipanel('Parent', fig, 'Units', 'pixels', ...
    'Position', [10, 10, panel_width, 860], 'BackgroundColor', [0.95 0.95 0.95]);

y = 820;
ui.title = uicontrol(ui.panel, 'Style', 'text', 'String', 'Function Plotter', ...
    'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', [0.85 0.90 0.95], ...
    'Position', [10, y, panel_width-20, 26]);

y = y - 35;
ui.type_label = uicontrol(ui.panel, 'Style', 'text', 'String', 'Input type:', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], ...
    'Position', [10, y, 120, 20]);
ui.radio_poly = uicontrol(ui.panel, 'Style', 'radiobutton', 'String', 'Poly', ...
    'Position', [130, y, 50, 22], 'BackgroundColor', [0.95 0.95 0.95], ...
    'Value', state.method == 1, 'Callback', @methodChanged);
ui.radio_fourier = uicontrol(ui.panel, 'Style', 'radiobutton', 'String', 'Fourier', ...
    'Position', [185, y, 65, 22], 'BackgroundColor', [0.95 0.95 0.95], ...
    'Value', state.method == 2, 'Callback', @methodChanged);

% Input mode toggle
y = y - 35;
ui.mode_label = uicontrol(ui.panel, 'Style', 'text', 'String', 'Input mode:', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], ...
    'Position', [10, y, 120, 20]);
ui.radio_text = uicontrol(ui.panel, 'Style', 'radiobutton', 'String', 'Text', ...
    'Position', [130, y, 55, 22], 'BackgroundColor', [0.95 0.95 0.95], ...
    'Value', strcmp(state.input_mode, 'text'), 'Callback', @inputModeChanged);
ui.radio_slider = uicontrol(ui.panel, 'Style', 'radiobutton', 'String', 'Sliders', ...
    'Position', [185, y, 65, 22], 'BackgroundColor', [0.95 0.95 0.95], ...
    'Value', strcmp(state.input_mode, 'slider'), 'Callback', @inputModeChanged);

%% Polynomial controls
y_poly = y - 45;
coeff_y_start = y_poly;
row_gap = 24;
ui.coeff_labels = zeros(1, max_terms+1);
ui.coeff_edits = zeros(1, max_terms+1);
ui.coeff_sliders = zeros(1, max_terms+1);
ui.coeff_vals = zeros(1, max_terms+1);
for i = 1:max_terms+1
    y_row = coeff_y_start - (i-1)*row_gap;
    ui.coeff_labels(i) = uicontrol(ui.panel, 'Style', 'text', 'String', sprintf('a%d', i-1), ...
        'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], ...
        'Position', [10, y_row, 60, 18]);
    ui.coeff_edits(i) = uicontrol(ui.panel, 'Style', 'edit', 'String', '0', ...
        'Position', [70, y_row-2, 140, 22], ...
        'Callback', {@coeffChanged, i}, 'Visible', 'on');
    ui.coeff_sliders(i) = uicontrol(ui.panel, 'Style', 'slider', 'Min', -10, 'Max', 10, 'Value', 0, ...
        'Position', [70, y_row, 140, 18], ...
        'SliderStep', [0.01 0.1], 'Callback', {@coeffSliderChanged, i}, 'Visible', 'off');
    ui.coeff_vals(i) = uicontrol(ui.panel, 'Style', 'text', 'String', '0', ...
        'BackgroundColor', [0.95 0.95 0.95], 'HorizontalAlignment', 'left', ...
        'Position', [215, y_row, 35, 18], 'Visible', 'off');
end

y_coeff_last = coeff_y_start - max_terms*row_gap;

%% Fourier controls
params_y_base = coeff_y_start - row_gap*max_fourier_terms - 15;
ui.f0_label = uicontrol(ui.panel, 'Style', 'text', 'String', 'Base frequency f0 (Hz):', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], ...
    'Position', [10, params_y_base, 170, 20], 'Visible', 'off');
ui.f0 = uicontrol(ui.panel, 'Style', 'edit', 'String', num2str(state.f0), ...
    'Position', [180, params_y_base-2, 70, 24], 'Callback', @f0Changed, 'Visible', 'off');

ui.dc_label = uicontrol(ui.panel, 'Style', 'text', 'String', 'DC (a0/2):', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], ...
    'Position', [10, params_y_base-30, 120, 20], 'Visible', 'off');
ui.dc = uicontrol(ui.panel, 'Style', 'edit', 'String', num2str(state.dc), ...
    'Position', [180, params_y_base-32, 70, 24], 'Callback', @dcChanged, 'Visible', 'off');

amp_y_start = coeff_y_start;
ui.amp_a_labels = zeros(1, max_fourier_terms);
ui.amp_a_edits = zeros(1, max_fourier_terms);
ui.amp_a_sliders = zeros(1, max_fourier_terms);
ui.amp_a_vals = zeros(1, max_fourier_terms);
ui.amp_b_labels = zeros(1, max_fourier_terms);
ui.amp_b_edits = zeros(1, max_fourier_terms);
ui.amp_b_sliders = zeros(1, max_fourier_terms);
ui.amp_b_vals = zeros(1, max_fourier_terms);

col_a_x = 5;
col_b_x = 133;
label_width = 20;
edit_width = 50;
slider_width = 73;
val_width = 25;

for i = 1:max_fourier_terms
    y_row = amp_y_start - (i-1)*row_gap;

    % Column A (cosine coefficients)
    ui.amp_a_labels(i) = uicontrol(ui.panel, 'Style', 'text', 'String', sprintf('a%d', i), ...
        'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], ...
        'Position', [col_a_x, y_row, label_width, 18], 'Visible', 'off');
    ui.amp_a_edits(i) = uicontrol(ui.panel, 'Style', 'edit', 'String', '0', ...
        'Position', [col_a_x+label_width, y_row-2, edit_width, 22], ...
        'Callback', {@ampAChanged, i}, 'Visible', 'off');
    ui.amp_a_sliders(i) = uicontrol(ui.panel, 'Style', 'slider', 'Min', -10, 'Max', 10, 'Value', 0, ...
        'Position', [col_a_x+label_width, y_row, slider_width, 18], ...
        'SliderStep', [0.01 0.1], 'Callback', {@ampASliderChanged, i}, 'Visible', 'off');
    ui.amp_a_vals(i) = uicontrol(ui.panel, 'Style', 'text', 'String', '0', ...
        'BackgroundColor', [0.95 0.95 0.95], 'HorizontalAlignment', 'left', ...
        'Position', [col_a_x+label_width+slider_width+2, y_row, val_width, 18], 'Visible', 'off');

    % Column B (sine coefficients)
    ui.amp_b_labels(i) = uicontrol(ui.panel, 'Style', 'text', 'String', sprintf('b%d', i), ...
        'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], ...
        'Position', [col_b_x, y_row, label_width, 18], 'Visible', 'off');
    ui.amp_b_edits(i) = uicontrol(ui.panel, 'Style', 'edit', 'String', '0', ...
        'Position', [col_b_x+label_width, y_row-2, edit_width, 22], ...
        'Callback', {@ampBChanged, i}, 'Visible', 'off');
    ui.amp_b_sliders(i) = uicontrol(ui.panel, 'Style', 'slider', 'Min', -10, 'Max', 10, 'Value', 0, ...
        'Position', [col_b_x+label_width, y_row, slider_width, 18], ...
        'SliderStep', [0.01 0.1], 'Callback', {@ampBSliderChanged, i}, 'Visible', 'off');
    ui.amp_b_vals(i) = uicontrol(ui.panel, 'Style', 'text', 'String', '0', ...
        'BackgroundColor', [0.95 0.95 0.95], 'HorizontalAlignment', 'left', ...
        'Position', [col_b_x+label_width+slider_width+2, y_row, val_width, 18], 'Visible', 'off');
end

layout.coeff_labels_pos = zeros(max_terms+1, 4);
layout.coeff_edits_pos  = zeros(max_terms+1, 4);
layout.coeff_sliders_pos = zeros(max_terms+1, 4);
layout.coeff_vals_pos   = zeros(max_terms+1, 4);
for i = 1:max_terms+1
    layout.coeff_labels_pos(i,:) = get(ui.coeff_labels(i), 'Position');
    layout.coeff_edits_pos(i,:)  = get(ui.coeff_edits(i), 'Position');
    layout.coeff_sliders_pos(i,:) = get(ui.coeff_sliders(i), 'Position');
    layout.coeff_vals_pos(i,:)   = get(ui.coeff_vals(i), 'Position');
end
layout.f0_label_pos = get(ui.f0_label, 'Position');
layout.f0_pos       = get(ui.f0, 'Position');
layout.dc_label_pos = get(ui.dc_label, 'Position');
layout.dc_pos       = get(ui.dc, 'Position');
layout.amp_a_labels_pos = zeros(max_fourier_terms, 4);
layout.amp_a_edits_pos  = zeros(max_fourier_terms, 4);
layout.amp_a_sliders_pos = zeros(max_fourier_terms, 4);
layout.amp_a_vals_pos   = zeros(max_fourier_terms, 4);
layout.amp_b_labels_pos = zeros(max_fourier_terms, 4);
layout.amp_b_edits_pos  = zeros(max_fourier_terms, 4);
layout.amp_b_sliders_pos = zeros(max_fourier_terms, 4);
layout.amp_b_vals_pos   = zeros(max_fourier_terms, 4);
for i = 1:max_fourier_terms
    layout.amp_a_labels_pos(i,:) = get(ui.amp_a_labels(i), 'Position');
    layout.amp_a_edits_pos(i,:)  = get(ui.amp_a_edits(i), 'Position');
    layout.amp_a_sliders_pos(i,:) = get(ui.amp_a_sliders(i), 'Position');
    layout.amp_a_vals_pos(i,:)   = get(ui.amp_a_vals(i), 'Position');
    layout.amp_b_labels_pos(i,:) = get(ui.amp_b_labels(i), 'Position');
    layout.amp_b_edits_pos(i,:)  = get(ui.amp_b_edits(i), 'Position');
    layout.amp_b_sliders_pos(i,:) = get(ui.amp_b_sliders(i), 'Position');
    layout.amp_b_vals_pos(i,:)   = get(ui.amp_b_vals(i), 'Position');
end

%% Transform button
y_transform = params_y_base - 70;
ui.transform_btn = uicontrol(ui.panel, 'Style', 'pushbutton', 'String', 'Transform', ...
    'FontWeight', 'bold', 'Position', [10, y_transform, panel_width-20, 24], 'Callback', @transformMode);

%% Time settings
y_time = params_y_base - 99;
ui.tstart_label = uicontrol(ui.panel, 'Style', 'text', 'String', 'Start time (s):', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], ...
    'Position', [10, y_time, 120, 20]);
ui.tstart = uicontrol(ui.panel, 'Style', 'edit', 'String', num2str(state.t_start), ...
    'Position', [180, y_time-2, 70, 24], 'Callback', @tstartChanged);

y_time = y_time - 30;
ui.tend_label = uicontrol(ui.panel, 'Style', 'text', 'String', 'End time (s):', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], ...
    'Position', [10, y_time, 120, 20]);
ui.tend = uicontrol(ui.panel, 'Style', 'edit', 'String', num2str(state.t_end), ...
    'Position', [180, y_time-2, 70, 24], 'Callback', @tendChanged);

y_time = y_time - 30;
ui.dt_label = uicontrol(ui.panel, 'Style', 'text', 'String', 'Time step dt (s):', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], ...
    'Position', [10, y_time, 140, 20]);
ui.dt = uicontrol(ui.panel, 'Style', 'edit', 'String', num2str(state.dt), ...
    'Position', [180, y_time-2, 70, 24], 'Callback', @dtChanged);

%% Buttons
y_btn = y_time - 40;
ui.export_btn = uicontrol(ui.panel, 'Style', 'pushbutton', 'String', 'Export', ...
    'FontWeight', 'bold', 'Position', [10, y_btn, 115, 24], 'Callback', @exportPlot);
ui.reset_btn = uicontrol(ui.panel, 'Style', 'pushbutton', 'String', 'Reset', ...
    'FontWeight', 'bold', 'Position', [135, y_btn, 115, 24], 'Callback', @resetAll);

%% Info box
y_info = y_btn - 10;
info_height = y_info - 10;
ui.info = uicontrol(ui.panel, 'Style', 'edit', 'String', '', ...
    'Max', 2, 'Min', 0, 'HorizontalAlignment', 'left', ...
    'Enable', 'inactive', 'BackgroundColor', [1 1 0.95], ...
    'Position', [10, 10, panel_width-20, info_height]);

set(fig, 'UserData', struct('ui', ui, 'state', state, 'ax', ax, 'max_terms', max_terms, 'max_poly_terms', max_poly_terms, 'max_fourier_terms', max_fourier_terms, 'layout', layout));

initialiseControls();
updatePlots();

%% =====================================================================
% Nested callbacks and helpers
%% =====================================================================

    function initialiseControls()
        data = get(fig, 'UserData');
        st = data.state;
        % Set radio buttons for method (Poly/Fourier)
        set(data.ui.radio_poly, 'Value', st.method == 1);
        set(data.ui.radio_fourier, 'Value', st.method == 2);
        % Set input mode radio buttons
        set(data.ui.radio_slider, 'Value', strcmp(st.input_mode, 'slider'));
        set(data.ui.radio_text, 'Value', strcmp(st.input_mode, 'text'));
        % Set parameter fields
        set(data.ui.f0, 'String', num2str(st.f0));
        set(data.ui.dc, 'String', num2str(st.dc));
        set(data.ui.tstart, 'String', num2str(st.t_start));
        set(data.ui.tend, 'String', num2str(st.t_end));
        set(data.ui.dt, 'String', num2str(st.dt));
        refreshCoeffEdits(st);
        refreshAmpEdits(st);
        toggleVisibility(st.method);
        set(fig, 'UserData', data);
    end

    function refreshCoeffEdits(st)
        data = get(fig, 'UserData');
        needed = data.max_terms + 1;
        coeffs = st.coeffs;
        if numel(coeffs) < needed
            coeffs = [zeros(1, needed - numel(coeffs)), coeffs];
        elseif numel(coeffs) > needed
            coeffs = coeffs(end-needed+1:end);
        end
        st.coeffs = coeffs;
        data.state = st;
        for i = 1:data.max_terms+1
            if i <= needed
                set(data.ui.coeff_edits(i), 'Visible', 'on');
                set(data.ui.coeff_sliders(i), 'Visible', 'on');
                set(data.ui.coeff_vals(i), 'Visible', 'on');
                set(data.ui.coeff_labels(i), 'Visible', 'on');
                % Map UI index i to polyval coefficient order (descending powers)
                coeff_idx = data.max_terms + 2 - i;
                set(data.ui.coeff_edits(i), 'String', num2str(coeffs(coeff_idx)));
                set(data.ui.coeff_sliders(i), 'Value', coeffs(coeff_idx));
                set(data.ui.coeff_vals(i), 'String', num2str(coeffs(coeff_idx),'%.3f'));
            else
                set(data.ui.coeff_edits(i), 'Visible', 'off');
                set(data.ui.coeff_sliders(i), 'Visible', 'off');
                set(data.ui.coeff_vals(i), 'Visible', 'off');
                set(data.ui.coeff_labels(i), 'Visible', 'off');
            end
        end
        set(fig, 'UserData', data);
    end

    function refreshAmpEdits(st)
        data = get(fig, 'UserData');
        for i = 1:max_fourier_terms
            % Column A (cosine)
            set(data.ui.amp_a_edits(i), 'String', num2str(st.amps_a(i)));
            set(data.ui.amp_a_sliders(i), 'Value', st.amps_a(i));
            set(data.ui.amp_a_vals(i), 'String', num2str(st.amps_a(i),'%.3f'));
            % Column B (sine)
            set(data.ui.amp_b_edits(i), 'String', num2str(st.amps_b(i)));
            set(data.ui.amp_b_sliders(i), 'Value', st.amps_b(i));
            set(data.ui.amp_b_vals(i), 'String', num2str(st.amps_b(i),'%.3f'));
        end
        set(fig, 'UserData', data);
    end

    function toggleVisibility(method_val)
        data = get(fig, 'UserData');
        show_poly = (method_val == 1);
        poly_controls = [data.ui.coeff_labels, data.ui.coeff_edits];
        fourier_controls_a = [data.ui.amp_a_labels, data.ui.amp_a_edits];
        fourier_controls_b = [data.ui.amp_b_labels, data.ui.amp_b_edits];
        fourier_params = [data.ui.f0_label, data.ui.f0, data.ui.dc_label, data.ui.dc];
        poly_sliders = [data.ui.coeff_sliders, data.ui.coeff_vals];
        fourier_sliders_a = [data.ui.amp_a_sliders, data.ui.amp_a_vals];
        fourier_sliders_b = [data.ui.amp_b_sliders, data.ui.amp_b_vals];
        set(poly_controls, 'Visible', ternary(show_poly, 'on', 'off'));
        set(poly_sliders, 'Visible', ternary(show_poly, 'on', 'off'));
        set(fourier_controls_a, 'Visible', ternary(show_poly, 'off', 'on'));
        set(fourier_sliders_a, 'Visible', ternary(show_poly, 'off', 'on'));
        set(fourier_controls_b, 'Visible', ternary(show_poly, 'off', 'on'));
        set(fourier_sliders_b, 'Visible', ternary(show_poly, 'off', 'on'));
        % f0 and dc are shown in Fourier mode, hidden in polynomial mode
        set(fourier_params, 'Visible', ternary(show_poly, 'off', 'on'));
        toggleInputMode(data.state.input_mode);
    end

    function v = ternary(cond, a, b)
        if cond
            v = a;
        else
            v = b;
        end
    end

    function inputModeChanged(src, ~)
        data = get(fig, 'UserData');
        if src == data.ui.radio_slider
            data.state.input_mode = 'slider';
            set(data.ui.radio_slider, 'Value', 1); set(data.ui.radio_text, 'Value', 0);
        else
            data.state.input_mode = 'text';
            set(data.ui.radio_slider, 'Value', 0); set(data.ui.radio_text, 'Value', 1);
        end
        toggleInputMode(data.state.input_mode);
    end

    function toggleInputMode(mode_val)
        data = get(fig, 'UserData');
        show_sliders = strcmp(mode_val, 'slider');
        show_poly = (data.state.method == 1);

        % Keep radio buttons in sync with the active input mode
        set(data.ui.radio_slider, 'Value', ternary(show_sliders, 1, 0));
        set(data.ui.radio_text,   'Value', ternary(show_sliders, 0, 1));

        if show_poly
            set(data.ui.coeff_edits, 'Visible', ternary(show_sliders, 'off', 'on'));
            set([data.ui.coeff_sliders, data.ui.coeff_vals], 'Visible', ternary(show_sliders, 'on', 'off'));
            set(data.ui.coeff_labels, 'Visible', 'on');
            set([data.ui.amp_a_edits, data.ui.amp_a_sliders, data.ui.amp_a_vals, data.ui.amp_a_labels], 'Visible', 'off');
            set([data.ui.amp_b_edits, data.ui.amp_b_sliders, data.ui.amp_b_vals, data.ui.amp_b_labels], 'Visible', 'off');
        else
            set(data.ui.amp_a_edits, 'Visible', ternary(show_sliders, 'off', 'on'));
            set([data.ui.amp_a_sliders, data.ui.amp_a_vals], 'Visible', ternary(show_sliders, 'on', 'off'));
            set(data.ui.amp_a_labels, 'Visible', 'on');
            set(data.ui.amp_b_edits, 'Visible', ternary(show_sliders, 'off', 'on'));
            set([data.ui.amp_b_sliders, data.ui.amp_b_vals], 'Visible', ternary(show_sliders, 'on', 'off'));
            set(data.ui.amp_b_labels, 'Visible', 'on');
            for i = 1:data.max_terms+1
                set(data.ui.coeff_edits(i), 'Visible', 'off');
                set(data.ui.coeff_sliders(i), 'Visible', 'off');
                set(data.ui.coeff_vals(i), 'Visible', 'off');
                set(data.ui.coeff_labels(i), 'Visible', 'off');
            end
        end
        set(fig, 'UserData', data);
    end

    function methodChanged(src, ~)
        data = get(fig, 'UserData');
        current_mode = data.state.input_mode;
        if src == data.ui.radio_poly
            val = 1;
            set(data.ui.radio_poly, 'Value', 1);
            set(data.ui.radio_fourier, 'Value', 0);
        else
            val = 2;
            set(data.ui.radio_poly, 'Value', 0);
            set(data.ui.radio_fourier, 'Value', 1);
        end

        data.state.method = val;

        % Explicitly show/hide controls based on method
        if val == 1
            set(data.ui.coeff_labels, 'Visible', 'on');
            set([data.ui.amp_a_labels, data.ui.amp_a_edits, data.ui.amp_a_sliders, data.ui.amp_a_vals], 'Visible', 'off');
            set([data.ui.amp_b_labels, data.ui.amp_b_edits, data.ui.amp_b_sliders, data.ui.amp_b_vals], 'Visible', 'off');
            set([data.ui.dc_label, data.ui.dc, data.ui.f0_label, data.ui.f0], 'Visible', 'off');
        else
            set(data.ui.amp_a_labels, 'Visible', 'on');
            set(data.ui.amp_b_labels, 'Visible', 'on');
            set([data.ui.dc_label, data.ui.dc, data.ui.f0_label, data.ui.f0], 'Visible', 'on');
            for i = 1:data.max_terms+1
                set(data.ui.coeff_labels(i), 'Visible', 'off');
                set(data.ui.coeff_edits(i), 'Visible', 'off');
                set(data.ui.coeff_sliders(i), 'Visible', 'off');
                set(data.ui.coeff_vals(i), 'Visible', 'off');
            end
        end

        set(fig, 'UserData', data);
        toggleInputMode(current_mode);
        data = get(fig, 'UserData');
        data.state.input_mode = current_mode;
        set(fig, 'UserData', data);
        updatePlots();
    end

    function coeffChanged(src, ~, idx)
        data = get(fig, 'UserData');
        val = str2double(get(src, 'String'));
        if isnan(val)
            val = 0;
        end
        needed = data.max_terms + 1;
        coeffs = data.state.coeffs;
        if numel(coeffs) < needed
            coeffs = [zeros(1, needed - numel(coeffs)), coeffs];
        elseif numel(coeffs) > needed
            coeffs = coeffs(end-needed+1:end);
        end
        % Map UI index idx to polyval coefficient order (descending powers)
        coeff_idx = data.max_terms + 2 - idx;
        coeffs(coeff_idx) = val;
        data.state.coeffs = coeffs;
        set(data.ui.coeff_sliders(idx), 'Value', val);
        set(data.ui.coeff_vals(idx), 'String', num2str(val,'%.3f'));
        set(fig, 'UserData', data);
        updatePlots();
    end

    function coeffSliderChanged(src, ~, idx)
        data = get(fig, 'UserData');
        val = get(src, 'Value');
        needed = data.max_terms + 1;
        coeffs = data.state.coeffs;
        if numel(coeffs) < needed
            coeffs = [zeros(1, needed - numel(coeffs)), coeffs];
        elseif numel(coeffs) > needed
            coeffs = coeffs(end-needed+1:end);
        end
        % Map UI index idx to polyval coefficient order (descending powers)
        coeff_idx = data.max_terms + 2 - idx;
        coeffs(coeff_idx) = val;
        data.state.coeffs = coeffs;
        set(data.ui.coeff_edits(idx), 'String', num2str(val));
        set(data.ui.coeff_vals(idx), 'String', num2str(val,'%.3f'));
        set(fig, 'UserData', data);
        updatePlots();
    end

    % removed harmonics count control; amplitudes always available

    function ampAChanged(src, ~, idx)
        data = get(fig, 'UserData');
        val = str2double(get(src, 'String'));
        if isnan(val)
            val = 0;
        end
        data.state.amps_a(idx) = val;
        set(data.ui.amp_a_sliders(idx), 'Value', val);
        set(data.ui.amp_a_vals(idx), 'String', num2str(val,'%.3f'));
        set(fig, 'UserData', data);
        updatePlots();
    end

    function ampASliderChanged(src, ~, idx)
        data = get(fig, 'UserData');
        val = get(src, 'Value');
        data.state.amps_a(idx) = val;
        set(data.ui.amp_a_edits(idx), 'String', num2str(val));
        set(data.ui.amp_a_vals(idx), 'String', num2str(val,'%.3f'));
        set(fig, 'UserData', data);
        updatePlots();
    end

    function ampBChanged(src, ~, idx)
        data = get(fig, 'UserData');
        val = str2double(get(src, 'String'));
        if isnan(val)
            val = 0;
        end
        data.state.amps_b(idx) = val;
        set(data.ui.amp_b_sliders(idx), 'Value', val);
        set(data.ui.amp_b_vals(idx), 'String', num2str(val,'%.3f'));
        set(fig, 'UserData', data);
        updatePlots();
    end

    function ampBSliderChanged(src, ~, idx)
        data = get(fig, 'UserData');
        val = get(src, 'Value');
        data.state.amps_b(idx) = val;
        set(data.ui.amp_b_edits(idx), 'String', num2str(val));
        set(data.ui.amp_b_vals(idx), 'String', num2str(val,'%.3f'));
        set(fig, 'UserData', data);
        updatePlots();
    end

    function f0Changed(src, ~)
        data = get(fig, 'UserData');
        val = str2double(get(src, 'String'));
        if isnan(val) || val <= 0
            val = 1;
        end
        if val < 1e-6
            val = 1e-6;
        elseif val > 1e6
            val = 1e6;
        end
        data.state.f0 = val;
        set(src, 'String', num2str(val));
        period = 1 / val;
        data.state.t_start = -period;
        data.state.t_end = period;
        set(data.ui.tstart, 'String', num2str(-period));
        set(data.ui.tend, 'String', num2str(period));
        data.state.dt = (data.state.t_end - data.state.t_start) / 200;
        set(data.ui.dt, 'String', num2str(data.state.dt));
        set(fig, 'UserData', data);
        updatePlots();
    end

    function dcChanged(src, ~)
        data = get(fig, 'UserData');
        val = str2double(get(src, 'String'));
        if isnan(val)
            val = 0;
        end
        data.state.dc = val;
        set(fig, 'UserData', data);
        updatePlots();
    end

    function tstartChanged(src, ~)
        data = get(fig, 'UserData');
        val = str2double(get(src, 'String'));
        if isnan(val)
            val = 0;
        end
        data.state.t_start = val;
        set(src, 'String', num2str(val));
        set(fig, 'UserData', data);
        updatePlots();
    end

    function tendChanged(src, ~)
        data = get(fig, 'UserData');
        val = str2double(get(src, 'String'));
        if isnan(val) || val <= 0
            val = 10;
        end
        data.state.t_end = val;
        set(src, 'String', num2str(val));
        set(fig, 'UserData', data);
        updatePlots();
    end

    function dtChanged(src, ~)
        data = get(fig, 'UserData');
        val = str2double(get(src, 'String'));
        if isnan(val) || val <= 0
            val = 0.01;
        end
        if val < 1e-6
            val = 1e-6;
        elseif val > 10
            val = 10;
        end
        data.state.dt = val;
        set(src, 'String', num2str(val));
        set(fig, 'UserData', data);
        updatePlots();
    end

    function resetAll(~, ~)
        data = get(fig, 'UserData');
        data.state = defaults;
        data.state.times_user_set = false;
        set(fig, 'UserData', data);
        initialiseControls();
        updatePlots();
    end

    function transformMode(~, ~)
        data = get(fig, 'UserData');
        st = data.state;
        prev_t_start = st.t_start;
        prev_t_end = st.t_end;
        prev_times_user_set = st.times_user_set;
        prev_dt = st.dt;

        if st.method == 1
            % Poly → Fourier: Compute Fourier coefficients from polynomial
            dt_val = max(st.dt, 1e-6);
            t_start_val = st.t_start;
            t_end_val = max(st.t_end, t_start_val + dt_val);
            t = t_start_val:dt_val:t_end_val;

            % Evaluate polynomial
            needed = data.max_poly_terms + 1;
            coeffs = st.coeffs;
            if numel(coeffs) < needed
                coeffs = [zeros(1, needed - numel(coeffs)), coeffs];
            elseif numel(coeffs) > needed
                coeffs = coeffs(end-needed+1:end);
            end
            sig = polyval(coeffs, t);

            % Compute Fourier coefficients
            T = t(end) - t(1);
            f0_new = 1 / T;
            a0 = (2 / T) * trapz(t, sig);
            amps_a_new = zeros(1, max_fourier_terms);
            amps_b_new = zeros(1, max_fourier_terms);
            for k = 1:max_fourier_terms
                amps_a_new(k) = (2 / T) * trapz(t, sig .* cos(2 * pi * k * f0_new * t));
                amps_b_new(k) = (2 / T) * trapz(t, sig .* sin(2 * pi * k * f0_new * t));
            end

            % Switch to Fourier mode and update state
            data.state.method = 2;
            data.state.f0 = f0_new;
            data.state.dc = a0/2;
            data.state.amps_a = amps_a_new;
            data.state.amps_b = amps_b_new;

            % Update UI
            set(data.ui.radio_poly, 'Value', 0);
            set(data.ui.radio_fourier, 'Value', 1);
            set(data.ui.f0, 'String', num2str(f0_new));
            set(data.ui.dc, 'String', num2str(a0/2));

        else
            % Fourier → Poly: Compute polynomial from Fourier using Taylor series
            omega = 2 * pi * st.f0;
            poly_coeffs = zeros(1, max_poly_terms + 1);
            poly_coeffs(1) = st.dc;  % a0/2 constant term

            % Add Taylor series for each harmonic
            for k = 1:max_fourier_terms
                % Cosine: cos(kωt) = Σ (-1)^n * (kωt)^(2n) / (2n)!
                factorial_2n = 1;
                for n = 0:floor(max_poly_terms/2)
                    if 2*n <= max_poly_terms
                        coeff = st.amps_a(k) * ((-1)^n * (omega*k)^(2*n) / factorial_2n);
                        poly_coeffs(2*n + 1) = poly_coeffs(2*n + 1) + coeff;
                    end
                    factorial_2n = factorial_2n * (2*n + 1) * (2*n + 2);
                end

                % Sine: sin(kωt) = Σ (-1)^n * (kωt)^(2n+1) / (2n+1)!
                factorial_2n1 = 1;
                for n = 0:floor((max_poly_terms-1)/2)
                    if 2*n + 1 <= max_poly_terms
                        coeff = st.amps_b(k) * ((-1)^n * (omega*k)^(2*n + 1) / factorial_2n1);
                        poly_coeffs(2*n + 2) = poly_coeffs(2*n + 2) + coeff;
                    end
                    factorial_2n1 = factorial_2n1 * (2*n + 2) * (2*n + 3);
                end
            end

            % Convert from a0, a1, ..., a11 to polyval format (highest power first)
            poly_coeffs_polyval = fliplr(poly_coeffs);

            % Switch to Polynomial mode and update state
            data.state.method = 1;
            data.state.coeffs = poly_coeffs_polyval;
            % Update UI
            set(data.ui.radio_poly, 'Value', 1);
            set(data.ui.radio_fourier, 'Value', 0);
        end

        set(fig, 'UserData', data);

        % Update visibility and refresh controls
        if data.state.method == 1
            set(data.ui.coeff_labels, 'Visible', 'on');
            set([data.ui.amp_a_labels, data.ui.amp_a_edits, data.ui.amp_a_sliders, data.ui.amp_a_vals], 'Visible', 'off');
            set([data.ui.amp_b_labels, data.ui.amp_b_edits, data.ui.amp_b_sliders, data.ui.amp_b_vals], 'Visible', 'off');
            set([data.ui.dc_label, data.ui.dc, data.ui.f0_label, data.ui.f0], 'Visible', 'off');
        else
            set(data.ui.amp_a_labels, 'Visible', 'on');
            set(data.ui.amp_b_labels, 'Visible', 'on');
            set([data.ui.dc_label, data.ui.dc, data.ui.f0_label, data.ui.f0], 'Visible', 'on');
            for i = 1:data.max_poly_terms+1
                set(data.ui.coeff_labels(i), 'Visible', 'off');
                set(data.ui.coeff_edits(i), 'Visible', 'off');
                set(data.ui.coeff_sliders(i), 'Visible', 'off');
                set(data.ui.coeff_vals(i), 'Visible', 'off');
            end
        end

        toggleInputMode(data.state.input_mode);
        refreshCoeffEdits(data.state);
        refreshAmpEdits(data.state);
        updatePlots();

        data = get(fig, 'UserData');
        data.state.t_start = prev_t_start;
        data.state.t_end = prev_t_end;
        data.state.times_user_set = prev_times_user_set;
        data.state.dt = prev_dt;
        set(data.ui.tstart, 'String', num2str(prev_t_start));
        set(data.ui.tend, 'String', num2str(prev_t_end));
        set(data.ui.dt, 'String', num2str(prev_dt));
        set(fig, 'UserData', data);
        toggleVisibility(data.state.method);
        toggleInputMode(data.state.input_mode);
        updatePlots();
    end

    function exportPlot(~, ~)
        data = get(fig, 'UserData');

        timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
        png_filename = sprintf('function_plot_%s.png', timestamp);
        txt_filename = sprintf('function_plot_%s.txt', timestamp);

        % Save PNG
        saveas(fig, png_filename);

        % Save TXT with info content
        info_text = get(data.ui.info, 'String');
        fid = fopen(txt_filename, 'w');
        fprintf(fid, '========================================\n');
        fprintf(fid, '  Function Plotter Export\n');
        fprintf(fid, '========================================\n');
        fprintf(fid, 'Generated: %s\n\n', datestr(now));

        fprintf(fid, 'CONFIGURATION\n');
        fprintf(fid, '-------------\n');
        fprintf(fid, 'Input Type: %s\n', ternary(data.state.method == 1, 'Polynomial', 'Fourier'));
        fprintf(fid, 'Input Mode: %s\n', data.state.input_mode);
        fprintf(fid, 'Time Range: [%.3f, %.3f] s\n', data.state.t_start, data.state.t_end);
        fprintf(fid, 'Time Step: %.5f s\n\n', data.state.dt);

        % Write info box content
        if iscell(info_text)
            for i = 1:length(info_text)
                fprintf(fid, '%s\n', info_text{i});
            end
        else
            fprintf(fid, '%s\n', info_text);
        end

        fprintf(fid, '\n========================================\n');
        fclose(fid);

        fprintf('\n===== EXPORT COMPLETE =====\n');
        fprintf('Plot saved to: %s\n', png_filename);
        fprintf('Info saved to: %s\n\n', txt_filename);
    end

    function updatePlots(~, ~)
        data = get(fig, 'UserData');
        st = data.state;
        dt_val = max(st.dt, 1e-6);
        t_start_val = st.t_start;
        t_end_val = max(st.t_end, t_start_val + dt_val);
        t = t_start_val:dt_val:t_end_val;
        if st.method == 1
            needed = data.max_poly_terms + 1;
            coeffs = st.coeffs;
            if numel(coeffs) < needed
                coeffs = [zeros(1, needed - numel(coeffs)), coeffs];
            elseif numel(coeffs) > needed
                coeffs = coeffs(end-needed+1:end);
            end
            st.coeffs = coeffs;
            time_vals = polyval(coeffs, t);
        else
            % Fourier mode: time axis in seconds
            time_vals = st.dc * ones(size(t));
            for k = 1:max_fourier_terms
                time_vals = time_vals + st.amps_a(k) * cos(2 * pi * k * st.f0 * t) + st.amps_b(k) * sin(2 * pi * k * st.f0 * t);
            end
            plot(data.ax, t, time_vals, 'LineWidth', 1.4);
            grid(data.ax, 'on');
            xlabel(data.ax, 'Time (s)');
            ylabel(data.ax, 'Amplitude');
            title(data.ax, 'Time plot (Fourier input)');
            xlim(data.ax, [st.t_start, st.t_end]);
            ylim(data.ax, 'auto');
            updateInfo(t, time_vals, st, data.max_fourier_terms);
            data.state = st;
            set(fig, 'UserData', data);
            return;
        end
        plot(data.ax, t, time_vals, 'LineWidth', 1.4);
        grid(data.ax, 'on');
        xlabel(data.ax, 'Time (s)');
        ylabel(data.ax, 'Amplitude');
        title(data.ax, ternary(st.method == 1, 'Time plot (polynomial input)', 'Time plot (Fourier input)'));
        xlim(data.ax, [st.t_start, st.t_end]);
        ylim(data.ax, 'auto');
        updateInfo(t, time_vals, st, data.max_poly_terms);
        data.state = st;
        set(fig, 'UserData', data);
    end

    function updateInfo(t, sig, st, max_terms)
        data = get(fig, 'UserData');
        if numel(t) < 2
            dt_local = st.dt;
        else
            dt_local = t(2) - t(1);
        end
        Fs = 1 / dt_local;
        info_lines = {};

        % Common header information
        info_lines{end+1} = sprintf('Time Range: [%.3f, %.3f] s', t(1), t(end));
        info_lines{end+1} = sprintf('Time Step: dt = %.5f s, Fs = %.2f Hz', dt_local, Fs);
        info_lines{end+1} = '';

        if st.method == 1
            % Polynomial mode - show polynomial coefficients then computed Fourier coefficients
            info_lines{end+1} = 'Polynomial Coefficients:';
            info_lines{end+1} = sprintf('f(t) = Σ a_k·t^k');
            for k = 0:max_terms
                coeff_idx = max_terms - k + 1;
                if k <= length(st.coeffs)
                    val = st.coeffs(coeff_idx);
                    if abs(val) < 1e-10, val = 0; end
                    info_lines{end+1} = sprintf('  a%d: %.4f', k, val);
                end
            end
            info_lines{end+1} = '';

            T = t(end) - t(1);
            f0_local = 1 / T;
            info_lines{end+1} = sprintf('Base Frequency: f0 = %.4f Hz (from time window)', f0_local);
            info_lines{end+1} = 'Fourier Series (periodic extension):';
            a0 = (2 / T) * trapz(t, sig);
            a = zeros(1, max_fourier_terms);
            b = zeros(1, max_fourier_terms);
            for k = 1:max_fourier_terms
                a(k) = (2 / T) * trapz(t, sig .* cos(2 * pi * k * f0_local * t));
                b(k) = (2 / T) * trapz(t, sig .* sin(2 * pi * k * f0_local * t));
            end
            dc_val = a0/2;
            if abs(dc_val) < 1e-10, dc_val = 0; end
            info_lines{end+1} = sprintf('DC (a0/2): %.4f', dc_val);
            info_lines{end+1} = '';
            info_lines{end+1} = 'Cosine Coefficients:';
            for k = 1:max_fourier_terms
                val = a(k);
                if abs(val) < 1e-10, val = 0; end
                info_lines{end+1} = sprintf('  a%d: %.4f', k, val);
            end
            info_lines{end+1} = '';
            info_lines{end+1} = 'Sine Coefficients:';
            for k = 1:max_fourier_terms
                val = b(k);
                if abs(val) < 1e-10, val = 0; end
                info_lines{end+1} = sprintf('  b%d: %.4f', k, val);
            end
        else
            % Fourier mode - show input coefficients and computed polynomial
            info_lines{end+1} = sprintf('Base Frequency: f0 = %.4f Hz', st.f0);
            info_lines{end+1} = 'Fourier Series Coefficients:';
            dc_val = st.dc;
            if abs(dc_val) < 1e-10, dc_val = 0; end
            info_lines{end+1} = sprintf('DC (a0/2): %.4f', dc_val);
            info_lines{end+1} = '';
            info_lines{end+1} = 'Cosine Coefficients:';
            for k = 1:max_terms
                val = st.amps_a(k);
                if abs(val) < 1e-10, val = 0; end
                info_lines{end+1} = sprintf('  a%d: %.4f', k, val);
            end
            info_lines{end+1} = '';
            info_lines{end+1} = 'Sine Coefficients:';
            for k = 1:max_fourier_terms
                val = st.amps_b(k);
                if abs(val) < 1e-10, val = 0; end
                info_lines{end+1} = sprintf('  b%d: %.4f', k, val);
            end

            % Compute polynomial representation from Fourier series using Taylor series
            info_lines{end+1} = '';
            info_lines{end+1} = 'Polynomial Approximation (via Taylor series):';
            % Build polynomial by summing Taylor series of each Fourier term
            poly_coeffs = zeros(1, max_poly_terms + 1);
            poly_coeffs(1) = st.dc;  % a0/2 constant term

            % Add Taylor series for each harmonic
            omega = 2 * pi * st.f0;
            for k = 1:max_fourier_terms
                % Cosine: cos(kωt) = Σ (-1)^n * (kωt)^(2n) / (2n)!
                factorial_2n = 1;
                for n = 0:floor(max_poly_terms/2)
                    if 2*n <= max_poly_terms
                        coeff = st.amps_a(k) * ((-1)^n * (omega*k)^(2*n) / factorial_2n);
                        poly_coeffs(2*n + 1) = poly_coeffs(2*n + 1) + coeff;
                    end
                    factorial_2n = factorial_2n * (2*n + 1) * (2*n + 2);
                end

                % Sine: sin(kωt) = Σ (-1)^n * (kωt)^(2n+1) / (2n+1)!
                factorial_2n1 = 1;
                for n = 0:floor((max_poly_terms-1)/2)
                    if 2*n + 1 <= max_poly_terms
                        coeff = st.amps_b(k) * ((-1)^n * (omega*k)^(2*n + 1) / factorial_2n1);
                        poly_coeffs(2*n + 2) = poly_coeffs(2*n + 2) + coeff;
                    end
                    factorial_2n1 = factorial_2n1 * (2*n + 2) * (2*n + 3);
                end
            end

            info_lines{end+1} = sprintf('f(t) = Σ a_k·t^k');
            for k = 0:max_poly_terms
                val = poly_coeffs(k + 1);
                if abs(val) < 1e-10, val = 0; end
                info_lines{end+1} = sprintf('  a%d: %.4f', k, val);
            end
        end
        set(data.ui.info, 'String', info_lines);
    end

end

% Allow calling without arguments as a script entry point
if ~isdeployed
    function_plotter();
end

