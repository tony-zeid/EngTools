#!/usr/bin/env python3
"""
Control System Response Analyser
Python/Tkinter version matching the MATLAB implementation

Allows interactive exploration of plant models with various controller types
Displays: Step Response, Impulse Response, Bode Magnitude, Bode Phase
"""

import tkinter as tk
from tkinter import ttk
import numpy as np
import matplotlib
matplotlib.use('TkAgg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
from scipy import signal
from datetime import datetime
import os

class ControlSystemGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Control System Response Analyser")
        self.root.geometry("1400x900")
        self.root.configure(bg='#f0f0f0')
        
        # Define plant models and parameters
        self.plant_models = [
            "Time Constant (1st Order)",
            "Natural Frequency & Damping", 
            "ODE Coefficients",
            "Laplace Transfer Function",
            "State Space Matrix"
        ]
        
        self.controller_types = [
            "None",
            "PID Controller",
            "State Feedback"
        ]
        
        # Parameter definitions
        self.define_parameters()
        
        # Current state
        self.current_plant = 0  # Time Constant (1st Order)
        self.current_controller = 0  # None
        self.input_mode = "slider"  # "slider" or "text"
        
        # Create UI
        self.create_ui()
        
        # Initialize with default values
        self.update_controls()
        self.update_plots()
        
    def define_parameters(self):
        """Define parameter structures for all models"""
        # Time Constant (1st Order): τ, K
        self.params_method1 = [
            {'name': 'Time Constant (τ)', 'label': 'τ', 'min': 0.1, 'max': 10, 'init': 1.0, 'step': 0.1},
            {'name': 'DC Gain (K)', 'label': 'K', 'min': 0.1, 'max': 10, 'init': 1.0, 'step': 0.1}
        ]
        
        # Natural Frequency & Damping: ωn, ζ, K
        self.params_method2 = [
            {'name': 'Natural Frequency (ωn)', 'label': 'ωn', 'min': 0.1, 'max': 50, 'init': 5.0, 'step': 0.5},
            {'name': 'Damping Ratio (ζ)', 'label': 'ζ', 'min': 0.01, 'max': 2, 'init': 0.7, 'step': 0.05},
            {'name': 'DC Gain (K)', 'label': 'K', 'min': 0.1, 'max': 10, 'init': 1.0, 'step': 0.1}
        ]
        
        # ODE Coefficients
        self.params_method3 = [
            {'name': 'a2 (coefficient of y″)', 'label': 'a2', 'min': 0, 'max': 10, 'init': 1.0, 'step': 0.1},
            {'name': 'a1 (coefficient of y′)', 'label': 'a1', 'min': 0, 'max': 50, 'init': 7.0, 'step': 0.1},
            {'name': 'a0 (coefficient of y)', 'label': 'a0', 'min': 0, 'max': 500, 'init': 25.0, 'step': 0.5},
            {'name': 'b (coefficient of u)', 'label': 'b', 'min': 0, 'max': 100, 'init': 25.0, 'step': 0.5}
        ]
        
        # Laplace Transfer Function
        self.params_method4 = [
            {'name': 'Numerator b0', 'label': 'b0', 'min': 0, 'max': 100, 'init': 25.0, 'step': 0.5},
            {'name': 'Denominator a2', 'label': 'a2', 'min': 0.01, 'max': 10, 'init': 1.0, 'step': 0.1},
            {'name': 'Denominator a1', 'label': 'a1', 'min': 0, 'max': 50, 'init': 7.0, 'step': 0.1},
            {'name': 'Denominator a0', 'label': 'a0', 'min': 0, 'max': 500, 'init': 25.0, 'step': 0.5}
        ]
        
        # State Space Matrix
        self.params_method5 = [
            {'name': 'A11 (state matrix)', 'label': 'A11', 'min': -50, 'max': 50, 'init': 0.0, 'step': 0.5},
            {'name': 'A12 (state matrix)', 'label': 'A12', 'min': -50, 'max': 50, 'init': 1.0, 'step': 0.5},
            {'name': 'A21 (state matrix)', 'label': 'A21', 'min': -50, 'max': 50, 'init': -25.0, 'step': 0.5},
            {'name': 'A22 (state matrix)', 'label': 'A22', 'min': -50, 'max': 50, 'init': -7.0, 'step': 0.5}
        ]
        
        # PID Controller
        self.params_pid = [
            {'name': 'Proportional Gain (Kp)', 'label': 'Kp', 'min': 0, 'max': 100, 'init': 1.0, 'step': 0.1},
            {'name': 'Integral Gain (Ki)', 'label': 'Ki', 'min': 0, 'max': 50, 'init': 0.0, 'step': 0.1},
            {'name': 'Derivative Gain (Kd)', 'label': 'Kd', 'min': 0, 'max': 20, 'init': 0.0, 'step': 0.1}
        ]
        
        # State Feedback
        self.params_statefb = [
            {'name': 'State Feedback Gain K1', 'label': 'K1', 'min': -100, 'max': 100, 'init': 1.0, 'step': 0.5},
            {'name': 'State Feedback Gain K2', 'label': 'K2', 'min': -100, 'max': 100, 'init': 1.0, 'step': 0.5}
        ]
        
        self.all_params = [
            self.params_method1,
            self.params_method2,
            self.params_method3,
            self.params_method4,
            self.params_method5
        ]
        
        self.controller_params = [
            [],
            self.params_pid,
            self.params_statefb
        ]
        
    def create_ui(self):
        """Create the main UI layout"""
        # Left panel for controls
        self.left_panel = tk.Frame(self.root, bg='#f0f0f0', width=260)
        self.left_panel.pack(side=tk.LEFT, fill=tk.Y, padx=5, pady=5)
        self.left_panel.pack_propagate(False)
        
        # Right panel for plots
        self.right_panel = tk.Frame(self.root, bg='white')
        self.right_panel.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        self.create_left_panel()
        self.create_plots()
        
    def create_left_panel(self):
        """Create all controls in the left panel"""
        y_pos = 10
        
        # Input mode radio buttons
        mode_frame = tk.Frame(self.left_panel, bg='#f0f0f0')
        mode_frame.place(x=15, y=y_pos, width=230, height=25)
        
        self.mode_var = tk.StringVar(value="slider")
        tk.Radiobutton(mode_frame, text="Sliders", variable=self.mode_var, value="slider",
                      command=self.on_mode_change, bg='#f0f0f0', font=('Arial', 10)).pack(side=tk.LEFT)
        tk.Radiobutton(mode_frame, text="Text Fields", variable=self.mode_var, value="text",
                      command=self.on_mode_change, bg='#f0f0f0', font=('Arial', 10)).pack(side=tk.LEFT, padx=20)
        
        y_pos += 40
        
        # Divider
        tk.Frame(self.left_panel, bg='#b0b0b0', height=2).place(x=10, y=y_pos, width=240)
        y_pos += 15
        
        # Reset and Export buttons
        btn_frame = tk.Frame(self.left_panel, bg='#f0f0f0')
        btn_frame.place(x=15, y=y_pos, width=230, height=35)
        
        tk.Button(btn_frame, text="Reset", font=('Arial', 10, 'bold'),
                 command=self.reset_callback).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 5))
        tk.Button(btn_frame, text="Export", font=('Arial', 10, 'bold'),
                 command=self.export_callback).pack(side=tk.LEFT, fill=tk.X, expand=True)
        
        y_pos += 45
        
        # Divider
        tk.Frame(self.left_panel, bg='#b0b0b0', height=2).place(x=10, y=y_pos, width=240)
        y_pos += 15
        
        # Plant section header
        plant_header = tk.Label(self.left_panel, text="PLANT", bg='#d9e5f0', fg='#333366',
                               font=('Arial', 10, 'bold'), relief=tk.RAISED)
        plant_header.place(x=10, y=y_pos, width=240, height=22)
        y_pos += 30
        
        # Plant model dropdown
        self.plant_var = tk.StringVar(value=self.plant_models[0])
        plant_combo = ttk.Combobox(self.left_panel, textvariable=self.plant_var,
                                   values=self.plant_models, state='readonly', font=('Arial', 10))
        plant_combo.place(x=15, y=y_pos, width=230, height=25)
        plant_combo.bind('<<ComboboxSelected>>', self.on_plant_change)
        y_pos += 35
        
        # State-space note (initially hidden)
        self.ss_note = tk.Label(self.left_panel, text="State Space: B=[0;1], C=[1,0], D=0",
                               bg='#f0f0ff', fg='#666699', font=('Arial', 8))
        
        # Plant parameters container
        self.plant_params_frame = tk.Frame(self.left_panel, bg='#f0f0f0')
        self.plant_params_frame.place(x=0, y=y_pos, width=260, height=350)
        
        y_pos += 360
        
        # Divider
        tk.Frame(self.left_panel, bg='#b0b0b0', height=2).place(x=10, y=y_pos, width=240)
        y_pos += 15
        
        # Controller section header
        controller_header = tk.Label(self.left_panel, text="CONTROLLER", bg='#f0e5d9', fg='#663333',
                                     font=('Arial', 10, 'bold'), relief=tk.RAISED)
        controller_header.place(x=10, y=y_pos, width=240, height=22)
        y_pos += 30
        
        # Controller type dropdown
        self.controller_var = tk.StringVar(value=self.controller_types[0])
        controller_combo = ttk.Combobox(self.left_panel, textvariable=self.controller_var,
                                       values=self.controller_types, state='readonly', font=('Arial', 10))
        controller_combo.place(x=15, y=y_pos, width=230, height=25)
        controller_combo.bind('<<ComboboxSelected>>', self.on_controller_change)
        y_pos += 35
        
        # Controller parameters container
        self.controller_params_frame = tk.Frame(self.left_panel, bg='#f0f0f0')
        self.controller_params_frame.place(x=0, y=y_pos, width=260, height=170)
        
        # Info panel at bottom
        self.info_text = tk.Text(self.left_panel, height=5, font=('Arial', 8),
                                bg='#fffef0', fg='#4d4d4d', relief=tk.SUNKEN, bd=1)
        self.info_text.place(x=10, y=820, width=240, height=80)
        self.info_text.insert('1.0', 'System Info')
        self.info_text.config(state=tk.DISABLED)
        
    def create_plots(self):
        """Create the 4 plot areas"""
        self.fig = Figure(figsize=(12, 8), facecolor='white')
        
        # Create 2x2 subplot grid
        self.ax1 = self.fig.add_axes([0.08, 0.55, 0.38, 0.38])  # Step response
        self.ax2 = self.fig.add_axes([0.57, 0.55, 0.38, 0.38])  # Impulse response
        self.ax3_mag = self.fig.add_axes([0.08, 0.08, 0.38, 0.38])  # Bode magnitude
        self.ax3_phase = self.fig.add_axes([0.57, 0.08, 0.38, 0.38])  # Bode phase
        
        self.canvas = FigureCanvasTkAgg(self.fig, master=self.right_panel)
        self.canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)
        
    def update_controls(self, preserve_values=False):
        """Update parameter controls based on current plant and controller"""
        # Save current values if preserving
        if preserve_values:
            saved_plant_values = self.get_plant_values()
            saved_controller_values = self.get_controller_values()
        else:
            saved_plant_values = None
            saved_controller_values = None
        
        # Clear existing controls
        for widget in self.plant_params_frame.winfo_children():
            widget.destroy()
        for widget in self.controller_params_frame.winfo_children():
            widget.destroy()
            
        # Show state-space note if method 5
        if self.current_plant == 4:
            self.ss_note.place(x=15, y=410, width=230, height=18)
        else:
            self.ss_note.place_forget()
        
        # Create plant parameter controls
        params = self.all_params[self.current_plant]
        self.plant_controls = []
        y = 0
        
        for i, param in enumerate(params):
            frame = tk.Frame(self.plant_params_frame, bg='#f0f0f0')
            frame.place(x=15, y=y, width=230, height=55)
            
            label = tk.Label(frame, text=param['name'], bg='#f0f0f0',
                           font=('Arial', 9, 'bold'), anchor='w')
            label.pack(fill=tk.X)
            
            # Use saved value if available, otherwise use default
            init_val = saved_plant_values[i] if (preserve_values and saved_plant_values and i < len(saved_plant_values)) else param['init']
            
            if self.input_mode == "slider":
                slider = tk.Scale(frame, from_=param['min'], to=param['max'],
                                resolution=param['step'], orient=tk.HORIZONTAL,
                                command=lambda v, idx=i: self.on_plant_param_change(idx, v),
                                bg='#f0f0f0', font=('Arial', 8))
                slider.set(init_val)
                slider.pack(fill=tk.X)
                
                value_label = tk.Label(frame, text=f"{param['label']} = {init_val:.1f}",
                                      bg='#f0f0ff', fg='#333366', font=('Arial', 9))
                value_label.pack(fill=tk.X)
                
                self.plant_controls.append({'slider': slider, 'label': value_label, 'param': param})
            else:
                entry = tk.Entry(frame, font=('Arial', 10))
                entry.insert(0, f"{init_val:.6g}")
                entry.bind('<Return>', lambda e, idx=i: self.on_plant_text_change(idx))
                entry.bind('<FocusOut>', lambda e, idx=i: self.on_plant_text_change(idx))
                entry.pack(fill=tk.X, pady=2)
                
                value_label = tk.Label(frame, text=f"{param['label']} = {init_val:.6g}",
                                      bg='#f0f0ff', fg='#333366', font=('Arial', 9))
                value_label.pack(fill=tk.X)
                
                self.plant_controls.append({'entry': entry, 'label': value_label, 'param': param})
            
            y += 58
        
        # Create controller parameter controls
        if self.current_controller > 0:
            params = self.controller_params[self.current_controller]
            self.controller_controls = []
            y = 0
            
            for i, param in enumerate(params):
                frame = tk.Frame(self.controller_params_frame, bg='#f0f0f0')
                frame.place(x=15, y=y, width=230, height=55)
                
                label = tk.Label(frame, text=param['name'], bg='#f0f0f0',
                               font=('Arial', 9, 'bold'), anchor='w')
                label.pack(fill=tk.X)
                
                # Use saved value if available, otherwise use default
                init_val = saved_controller_values[i] if (preserve_values and saved_controller_values and i < len(saved_controller_values)) else param['init']
                
                if self.input_mode == "slider":
                    slider = tk.Scale(frame, from_=param['min'], to=param['max'],
                                    resolution=param['step'], orient=tk.HORIZONTAL,
                                    command=lambda v, idx=i: self.on_controller_param_change(idx, v),
                                    bg='#f0f0f0', font=('Arial', 8))
                    slider.set(init_val)
                    slider.pack(fill=tk.X)
                    
                    value_label = tk.Label(frame, text=f"{param['label']} = {init_val:.1f}",
                                          bg='#fff0e8', fg='#664433', font=('Arial', 9))
                    value_label.pack(fill=tk.X)
                    
                    self.controller_controls.append({'slider': slider, 'label': value_label, 'param': param})
                else:
                    entry = tk.Entry(frame, font=('Arial', 10))
                    entry.insert(0, f"{init_val:.6g}")
                    entry.bind('<Return>', lambda e, idx=i: self.on_controller_text_change(idx))
                    entry.bind('<FocusOut>', lambda e, idx=i: self.on_controller_text_change(idx))
                    entry.pack(fill=tk.X, pady=2)
                    
                    value_label = tk.Label(frame, text=f"{param['label']} = {init_val:.6g}",
                                          bg='#fff0e8', fg='#664433', font=('Arial', 9))
                    value_label.pack(fill=tk.X)
                    
                    self.controller_controls.append({'entry': entry, 'label': value_label, 'param': param})
                
                y += 58
        else:
            self.controller_controls = []
    
    def get_plant_values(self):
        """Get current plant parameter values"""
        values = []
        for control in self.plant_controls:
            if 'slider' in control:
                values.append(control['slider'].get())
            else:
                try:
                    values.append(float(control['entry'].get()))
                except:
                    values.append(control['param']['init'])
        return values
    
    def get_controller_values(self):
        """Get current controller parameter values"""
        if not hasattr(self, 'controller_controls') or not self.controller_controls:
            return []
        values = []
        for control in self.controller_controls:
            if 'slider' in control:
                values.append(control['slider'].get())
            else:
                try:
                    values.append(float(control['entry'].get()))
                except:
                    values.append(control['param']['init'])
        return values
    
    def on_mode_change(self):
        """Handle input mode change"""
        self.input_mode = self.mode_var.get()
        self.update_controls(preserve_values=True)
        self.update_plots()
    
    def on_plant_change(self, event=None):
        """Handle plant model change"""
        self.current_plant = self.plant_models.index(self.plant_var.get())
        self.update_controls()
        self.update_plots()
    
    def on_controller_change(self, event=None):
        """Handle controller type change"""
        self.current_controller = self.controller_types.index(self.controller_var.get())
        self.update_controls()
        self.update_plots()
    
    def on_plant_param_change(self, idx, value):
        """Handle plant parameter change"""
        control = self.plant_controls[idx]
        val = float(value)
        control['label'].config(text=f"{control['param']['label']} = {val:.1f}")
        self.update_plots()
    
    def on_plant_text_change(self, idx):
        """Handle plant text entry change"""
        control = self.plant_controls[idx]
        try:
            val = float(control['entry'].get())
            control['label'].config(text=f"{control['param']['label']} = {val:.6g}")
            self.update_plots()
        except:
            pass
    
    def on_controller_param_change(self, idx, value):
        """Handle controller parameter change"""
        control = self.controller_controls[idx]
        val = float(value)
        control['label'].config(text=f"{control['param']['label']} = {val:.1f}")
        self.update_plots()
    
    def on_controller_text_change(self, idx):
        """Handle controller text entry change"""
        control = self.controller_controls[idx]
        try:
            val = float(control['entry'].get())
            control['label'].config(text=f"{control['param']['label']} = {val:.6g}")
            self.update_plots()
        except:
            pass
    
    def convert_to_tf(self, values, method):
        """Convert plant parameters to transfer function"""
        if method == 0:  # Time Constant (1st Order)
            tau, K = values
            tau = max(tau, 1e-6)  # Prevent zero denominator
            num = [K]
            den = [tau, 1]
            wn = 1.0 / tau
            zeta = 1.0
            dc_gain = K
        elif method == 1:  # Natural Frequency & Damping
            wn, zeta, K = values
            num = [K * wn**2]
            den = [1, 2*zeta*wn, wn**2]
            dc_gain = K
        elif method == 2:  # ODE coefficients
            a2, a1, a0, b = values
            a2 = max(abs(a2), 1e-6)
            a0 = max(abs(a0), 1e-6)
            num = [max(b/a2, 1e-12)]
            den = [1, a1/a2, a0/a2]
            wn = np.sqrt(a0/a2) if a0/a2 > 0 else 1.0
            zeta = a1/(2*np.sqrt(a0*a2)) if a0*a2 > 0 else 1.0
            dc_gain = b/a0 if abs(a0) > 1e-12 else 1.0
        elif method == 3:  # Laplace Transfer Function
            b0, a2, a1, a0 = values
            a2 = max(abs(a2), 1e-6)
            a0 = max(abs(a0), 1e-6)
            num = [max(b0/a2, 1e-12)]
            den = [1, a1/a2, a0/a2]
            wn = np.sqrt(a0/a2) if a0/a2 > 0 else 1.0
            zeta = a1/(2*np.sqrt(a0*a2)) if a0*a2 > 0 else 1.0
            dc_gain = b0/a0 if abs(a0) > 1e-12 else 1.0
        elif method == 4:  # State Space Matrix
            A11, A12, A21, A22 = values
            # Convert to TF: C*(sI-A)^-1*B with B=[0;1], C=[1,0]
            # TF = A12 / (s^2 - (A11+A22)*s + det(A))
            det_A = A11*A22 - A12*A21
            trace_A = A11 + A22
            num = [A12]
            den = [1, -trace_A, det_A]
            # Extract wn, zeta
            if det_A > 0:
                wn = np.sqrt(det_A)
                zeta = -trace_A / (2*wn)
            else:
                wn = 1.0
                zeta = 1.0
            dc_gain = A12/det_A if abs(det_A) > 1e-12 else 1.0
        
        return num, den, wn, zeta, dc_gain
    
    def compute_closed_loop(self, num_plant, den_plant, controller_values):
        """Compute closed-loop transfer function"""
        if self.current_controller == 0:  # No controller
            return num_plant, den_plant
        elif self.current_controller == 1:  # PID
            Kp, Ki, Kd = controller_values
            # C(s) = Kp + Ki/s + Kd*s = (Kd*s^2 + Kp*s + Ki)/s
            num_c = [Kd, Kp, Ki]
            den_c = [1, 0]
            
            # Series connection
            num_ol = np.convolve(num_c, num_plant)
            den_ol = np.convolve(den_c, den_plant)
            
            # Closed-loop with unity feedback
            num_cl = num_ol
            den_cl = np.polyadd(den_ol, num_ol)
            
            return num_cl, den_cl
        elif self.current_controller == 2:  # State feedback
            plant_values = self.get_plant_values()
            if self.current_plant == 4 and len(plant_values) >= 4:
                # True state-space implementation
                A11, A12, A21, A22 = plant_values
                K1, K2 = controller_values
                
                # A_cl = A - B*K with B=[0;1]
                A_cl = np.array([[A11, A12], [A21 - K1, A22 - K2]])
                
                # Characteristic polynomial
                det_Acl = np.linalg.det(A_cl)
                trace_Acl = np.trace(A_cl)
                den_cl = [1, -trace_Acl, det_Acl]
                
                # Numerator: C*adj(sI-A_cl)*B with C=[1,0], B=[0;1]
                num_cl = [0, 0, A_cl[0, 1]]
                if abs(A_cl[0, 1]) < 1e-12:
                    num_cl = [0, 0, 1e-6]
                
                return num_cl, den_cl
            else:
                # Simplified output feedback
                K_eff = sum(controller_values)
                num_ol = K_eff * np.array(num_plant)
                den_ol = den_plant
                num_cl = num_ol
                den_cl = np.polyadd(den_ol, num_ol)
                
                return num_cl, den_cl
        
        return num_plant, den_plant
    
    def update_plots(self):
        """Update all plots with current parameters"""
        try:
            # Get plant values and convert to TF
            plant_values = self.get_plant_values()
            num_plant, den_plant, wn, zeta, K = self.convert_to_tf(plant_values, self.current_plant)
            
            # Get controller values and compute closed-loop
            controller_values = self.get_controller_values()
            num_cl, den_cl = self.compute_closed_loop(num_plant, den_plant, controller_values)
            
            # Create transfer function with validation
            # Ensure numerator is not all zeros
            if np.all(np.abs(num_cl) < 1e-12):
                num_cl = [1e-12]
            # Ensure denominator is not all zeros
            if np.all(np.abs(den_cl) < 1e-12):
                den_cl = [1, 1]
            
            sys_cl = signal.TransferFunction(num_cl, den_cl)
            
            # Compute poles
            poles_cl = np.roots(den_cl)
            
            # Determine time vector
            max_real = np.max(np.real(poles_cl))
            if max_real < 0 and not np.isnan(max_real):
                T_settle = max(4.0 / abs(max_real), 1.0)
            else:
                T_settle = 10.0
            t = np.linspace(0, T_settle * 4, 1000)
            
            # Plot 1: Step Response
            self.ax1.clear()
            _, y_step = signal.step(sys_cl, T=t)
            self.ax1.plot(t, y_step, 'b-', linewidth=2.5)
            self.ax1.grid(True, alpha=0.3)
            self.ax1.set_xlabel('Time (s)', fontsize=11)
            self.ax1.set_ylabel('Output', fontsize=11)
            if self.current_controller == 0:
                self.ax1.set_title('Step Response (Open Loop)', fontsize=14, fontweight='bold')
            else:
                self.ax1.set_title('Step Response (Closed Loop)', fontsize=14, fontweight='bold')
            
            # Plot 2: Impulse Response
            self.ax2.clear()
            _, y_impulse = signal.impulse(sys_cl, T=t)
            self.ax2.plot(t, y_impulse, 'b-', linewidth=2.5)
            self.ax2.grid(True, alpha=0.3)
            self.ax2.set_xlabel('Time (s)', fontsize=11)
            self.ax2.set_ylabel('Output', fontsize=11)
            if self.current_controller == 0:
                self.ax2.set_title('Impulse Response (Open Loop)', fontsize=14, fontweight='bold')
            else:
                self.ax2.set_title('Impulse Response (Closed Loop)', fontsize=14, fontweight='bold')
            
            # Plot 3: Bode Magnitude
            self.ax3_mag.clear()
            omega = np.logspace(-2, 2, 300)
            w, mag, phase = signal.bode(sys_cl, omega)
            # Clip very small magnitude values to prevent log10(0)
            mag = np.clip(mag, -200, 200)
            self.ax3_mag.semilogx(w, mag, 'b-', linewidth=2.5)
            self.ax3_mag.grid(True, alpha=0.3, which='both')
            self.ax3_mag.set_xlabel('Frequency (rad/s)', fontsize=11)
            self.ax3_mag.set_ylabel('Magnitude (dB)', fontsize=11)
            self.ax3_mag.set_title('Bode Magnitude', fontsize=14, fontweight='bold')
            
            # Add -3dB marker
            idx_3db = np.where(mag <= -3)[0]
            if len(idx_3db) > 0:
                idx = idx_3db[0]
                if idx > 0:
                    omega_3db = np.interp(-3, [mag[idx-1], mag[idx]], [w[idx-1], w[idx]])
                    ylims = self.ax3_mag.get_ylim()
                    self.ax3_mag.plot([omega_3db, omega_3db], ylims, 'r--', linewidth=1.5)
                    self.ax3_mag.plot(omega_3db, -3, 'ro', markersize=8, markerfacecolor='r')
                    self.ax3_mag.text(omega_3db*1.15, -3, f'-3dB: {omega_3db:.2f} rad/s',
                                     fontsize=9, color='r')
            
            # Plot 4: Bode Phase
            self.ax3_phase.clear()
            self.ax3_phase.semilogx(w, phase, 'b-', linewidth=2.5)
            self.ax3_phase.grid(True, alpha=0.3, which='both')
            self.ax3_phase.set_xlabel('Frequency (rad/s)', fontsize=11)
            self.ax3_phase.set_ylabel('Phase (degrees)', fontsize=11)
            self.ax3_phase.set_title('Bode Phase', fontsize=14, fontweight='bold')
            self.ax3_phase.set_yticks(np.arange(-180, 1, 45))
            
            # Add phase markers
            ylims = self.ax3_phase.get_ylim()
            for target_phase, label in [(-45, '-45°'), (-90, '-90°'), (-135, '-135°')]:
                idx = np.where(phase <= target_phase)[0]
                if len(idx) > 0:
                    idx_cross = idx[0]
                    if idx_cross > 0:
                        omega_cross = np.interp(target_phase,
                                               [phase[idx_cross-1], phase[idx_cross]],
                                               [w[idx_cross-1], w[idx_cross]])
                        self.ax3_phase.plot([omega_cross, omega_cross], ylims, 'r--', linewidth=1.2)
                        self.ax3_phase.plot(omega_cross, target_phase, 'ro', markersize=6, markerfacecolor='r')
                        self.ax3_phase.text(omega_cross*1.15, target_phase,
                                          f'{label}: {omega_cross:.2f} rad/s',
                                          fontsize=9, color='r')
            
            self.canvas.draw()
            
            # Update info panel
            self.update_info(poles_cl, wn, zeta)
            
        except Exception as e:
            print(f"Error updating plots: {e}")
            import traceback
            traceback.print_exc()
    
    def update_info(self, poles_cl, wn_plant, zeta_plant):
        """Update the info text panel"""
        try:
            # Stability
            is_stable = np.all(np.real(poles_cl) < -1e-6)
            stability_str = "Stable ✓" if is_stable else "UNSTABLE ✗"
            
            # Closed-loop damping
            cl_wn = np.abs(poles_cl[0])
            if np.abs(np.imag(poles_cl[0])) > 1e-6:
                cl_zeta = max(0, -np.real(poles_cl[0]) / np.abs(poles_cl[0]))
            else:
                cl_zeta = 1.0
            
            # Performance metrics
            overshoot = 0
            settling = np.nan
            if 0 < cl_zeta < 1:
                overshoot = np.exp(-cl_zeta*np.pi/np.sqrt(1-cl_zeta**2)) * 100
                if cl_zeta * cl_wn > 0:
                    settling = 4 / (cl_zeta * cl_wn)
            elif cl_zeta >= 1 and cl_wn > 0:
                settling = 4 / (cl_zeta * cl_wn)
                overshoot = 0
            
            # Build info string
            info_lines = [stability_str]
            info_lines.append(f"CL: ωn={cl_wn:.1f}, ζ={cl_zeta:.2f}")
            
            controller_values = self.get_controller_values()
            if self.current_controller == 1:  # PID
                Kp, Ki, Kd = controller_values
                info_lines.append(f"Kp={Kp:.2f} Ki={Ki:.2f} Kd={Kd:.2f}")
            elif self.current_controller == 2:  # State feedback
                K1, K2 = controller_values
                info_lines.append(f"K₁={K1:.2f} K₂={K2:.2f}")
            else:
                info_lines.append("Open Loop")
            
            # Poles
            if len(poles_cl) >= 2:
                if np.abs(np.imag(poles_cl[0])) > 1e-6:
                    info_lines.append(f"P: {np.real(poles_cl[0]):.2f}±j{np.abs(np.imag(poles_cl[0])):.2f}")
                else:
                    info_lines.append(f"P: {poles_cl[0]:.3f}, {poles_cl[1]:.3f}")
            
            # Performance
            if not np.isnan(settling):
                info_lines.append(f"OS={overshoot:.0f}% Ts={settling:.2f}s")
            
            info_str = '\n'.join(info_lines)
            
            self.info_text.config(state=tk.NORMAL)
            self.info_text.delete('1.0', tk.END)
            self.info_text.insert('1.0', info_str)
            self.info_text.config(state=tk.DISABLED)
            
        except Exception as e:
            print(f"Error updating info: {e}")
    
    def reset_callback(self):
        """Reset all parameters to defaults"""
        self.update_controls()
        self.update_plots()
    
    def export_callback(self):
        """Export system data and plots"""
        try:
            timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
            filename = f'system_response_{timestamp}.txt'
            
            # Get current system
            plant_values = self.get_plant_values()
            controller_values = self.get_controller_values()
            num_plant, den_plant, wn, zeta, K = self.convert_to_tf(plant_values, self.current_plant)
            num_cl, den_cl = self.compute_closed_loop(num_plant, den_plant, controller_values)
            sys_cl = signal.TransferFunction(num_cl, den_cl)
            poles_cl = np.roots(den_cl)
            zeros_cl = np.roots(num_cl)
            
            # Write text file
            with open(filename, 'w') as f:
                f.write('=' * 40 + '\n')
                f.write('  System Response Analysis Export\n')
                f.write('=' * 40 + '\n')
                f.write(f'Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}\n\n')
                
                # Configuration
                f.write('SYSTEM CONFIGURATION\n')
                f.write('-' * 20 + '\n')
                f.write(f'Plant Model: {self.plant_models[self.current_plant]}\n')
                f.write(f'Controller: {self.controller_types[self.current_controller]}\n')
                f.write(f'Input Mode: {self.input_mode}\n\n')
                
                # Plant parameters
                f.write('PLANT PARAMETERS\n')
                f.write('-' * 16 + '\n')
                params = self.all_params[self.current_plant]
                for i, val in enumerate(plant_values):
                    f.write(f"{params[i]['label']} = {val:.6g}\n")
                f.write('\n')
                
                # Plant characteristics
                f.write('PLANT CHARACTERISTICS\n')
                f.write('-' * 21 + '\n')
                f.write(f'Natural Frequency (ωn): {wn:.4f} rad/s\n')
                f.write(f'Damping Ratio (ζ): {zeta:.4f}\n')
                f.write(f'DC Gain (K): {K:.4f}\n\n')
                
                # Controller parameters
                if self.current_controller > 0:
                    f.write('CONTROLLER PARAMETERS\n')
                    f.write('-' * 21 + '\n')
                    params = self.controller_params[self.current_controller]
                    for i, val in enumerate(controller_values):
                        f.write(f"{params[i]['label']} = {val:.6g}\n")
                    f.write('\n')
                
                # Closed-loop characteristics
                f.write('CLOSED-LOOP CHARACTERISTICS\n')
                f.write('-' * 28 + '\n')
                
                is_stable = np.all(np.real(poles_cl) < -1e-6)
                f.write(f'Stability: {"STABLE" if is_stable else "UNSTABLE"}\n')
                
                f.write('Closed-Loop Poles:\n')
                for i, pole in enumerate(poles_cl):
                    if np.abs(np.imag(pole)) > 1e-6:
                        f.write(f'  p{i+1} = {np.real(pole):.6f} ± j{np.abs(np.imag(pole)):.6f}\n')
                    else:
                        f.write(f'  p{i+1} = {np.real(pole):.6f}\n')
                
                f.write('Closed-Loop Zeros:\n')
                if len(zeros_cl) == 0 or np.all(np.abs(zeros_cl) < 1e-12):
                    f.write('  (none)\n')
                else:
                    for i, zero in enumerate(zeros_cl):
                        if np.abs(np.imag(zero)) > 1e-6:
                            f.write(f'  z{i+1} = {np.real(zero):.6f} ± j{np.abs(np.imag(zero)):.6f}\n')
                        else:
                            f.write(f'  z{i+1} = {np.real(zero):.6f}\n')
                
                # Damping and performance
                cl_wn = np.abs(poles_cl[0])
                if np.abs(np.imag(poles_cl[0])) > 1e-6:
                    cl_zeta = max(0, -np.real(poles_cl[0]) / np.abs(poles_cl[0]))
                else:
                    cl_zeta = 1.0
                
                f.write(f'CL Natural Frequency: {cl_wn:.4f} rad/s\n')
                f.write(f'CL Damping Ratio: {cl_zeta:.4f}\n')
                
                overshoot = np.nan
                settling = np.nan
                if 0 < cl_zeta < 1:
                    overshoot = np.exp(-cl_zeta*np.pi/np.sqrt(1-cl_zeta**2)) * 100
                    if cl_zeta * cl_wn > 0:
                        settling = 4 / (cl_zeta * cl_wn)
                elif cl_zeta >= 1 and cl_wn > 0:
                    settling = 4 / (cl_zeta * cl_wn)
                    overshoot = 0
                
                if not np.isnan(overshoot):
                    f.write(f'Est. Overshoot: {overshoot:.2f} %\n')
                if not np.isnan(settling):
                    f.write(f'Est. Settling Time (4%): {settling:.3f} s\n')
                
                # Frequency domain
                f.write('\nFREQUENCY DOMAIN CHARACTERISTICS\n')
                f.write('-' * 32 + '\n')
                
                omega = np.logspace(-2, 2, 300)
                w, mag, phase = signal.bode(sys_cl, omega)
                
                # -3dB bandwidth
                idx_3db = np.where(mag <= -3)[0]
                if len(idx_3db) > 0 and idx_3db[0] > 0:
                    omega_3db = np.interp(-3, [mag[idx_3db[0]-1], mag[idx_3db[0]]],
                                         [w[idx_3db[0]-1], w[idx_3db[0]]])
                    f.write(f'-3dB Bandwidth: {omega_3db:.4f} rad/s ({omega_3db/(2*np.pi):.4f} Hz)\n')
                else:
                    f.write('-3dB Bandwidth: N/A\n')
                
                # Phase crossovers
                for target, label in [(-45, '-45°'), (-90, '-90°'), (-135, '-135°')]:
                    idx = np.where(phase <= target)[0]
                    if len(idx) > 0 and idx[0] > 0:
                        omega_cross = np.interp(target, [phase[idx[0]-1], phase[idx[0]]],
                                               [w[idx[0]-1], w[idx[0]]])
                        f.write(f'{label} Phase Crossover: {omega_cross:.4f} rad/s ({omega_cross/(2*np.pi):.4f} Hz)\n')
                    else:
                        f.write(f'{label} Phase Crossover: N/A\n')
                
                f.write('\n' + '=' * 40 + '\n')
            
            # Save plot
            img_filename = f'system_response_{timestamp}.png'
            self.fig.savefig(img_filename, dpi=150, bbox_inches='tight')
            
            print(f'\n===== EXPORT COMPLETE =====')
            print(f'Full analysis saved to: {filename}')
            print(f'Figure saved to: {img_filename}\n')
            
        except Exception as e:
            print(f"Error exporting: {e}")
            import traceback
            traceback.print_exc()

def main():
    root = tk.Tk()
    app = ControlSystemGUI(root)
    root.mainloop()

if __name__ == '__main__':
    main()
