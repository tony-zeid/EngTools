# mTools

Series of simple engineering tools using Matlab (Octave compatible) and Python.

## MATLAB tools

- `matlab/control_system_response.m`: Interactive control system response analyzer for a second-order plant with optional controllers. Shows step response, impulse response, and Bode plots with live parameter updates.
- `matlab/function_plotter.m`: Function plotter for polynomial and Fourier series input. Supports text/sliders, time window controls, and exporting plots.

## Python tools

### Control system response

- `python/control_system_response.py`: Tkinter GUI version of the control system response analyzer. Mirrors the MATLAB behavior with interactive parameters and Matplotlib plots.
- `python/control_system_response_flet.py`: Flet GUI version of the control system response analyzer for desktop or web.

### Function plotter

- `python/function_plotter.py`: Tkinter GUI function plotter for polynomial and Fourier series input. Includes time controls and live plot updates.
- `python/function_plotter_cli.py`: Command-line function plotter with interactive prompts and Matplotlib plotting/export.
- `python/function_plotter_flet.py`: Flet GUI function plotter for desktop or web.

## Running the tools

### MATLAB / Octave

- Open the `.m` files directly in MATLAB or Octave and run them.

### Python (Tkinter / CLI)

- Run a Tkinter GUI:

```bash
python3 python/control_system_response.py
python3 python/function_plotter.py
```

- Run the CLI function plotter:

```bash
python3 python/function_plotter_cli.py
```

### Python (Flet)

- Run a Flet app:

```bash
flet run python/control_system_response_flet.py
flet run python/function_plotter_flet.py
```

## Future additions

Planned tool categories:

- Signal processing and analysis (FFT, filters, convolution/correlation)
- Circuit and electrical calculators (AC/DC, RLC, transformers, transmission lines)
- Power electronics and switching (PWM, DC-DC converters, rectifiers)
- Mechanical simulation (vibration, beam bending, kinematics)
- Control and optimization (root locus, state-space conversion, pole-zero maps, LQR/LQG)
- Numerical methods suite (solvers, integration/differentiation, ODEs, regression)
- Statistical and data tools (curve fitting, hypothesis testing, Monte Carlo)
- Embedded and real-time (fixed-point analysis, timing, stateflow logic tests)
- Thermal and fluid tools (heat transfer, fluid dynamics, pump sizing)
- Robotics and motion (trajectory planning, Jacobian tools, DH parameters)
- Math utilities (matrix analysis, symbolic tools, complex plots)

Feature ideas and integrations:

- Export results to PDF, LaTeX, or Excel
- GUI front-ends (MATLAB App, Python Qt, Plotly Dash)
- Parameter sweeps and optimization batch runs
- Live data input from instruments (serial, UDP, TCP)
- Report generation templates
