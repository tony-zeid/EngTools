#!/usr/bin/env python3
"""
Function Plotter - Tkinter GUI
Python/Tkinter version matching the MATLAB implementation

Allows interactive exploration of polynomial and Fourier functions
Displays: Time-domain plot with real-time updates
"""

import tkinter as tk
from tkinter import ttk
import numpy as np
import matplotlib
matplotlib.use('TkAgg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
from scipy import fftpack
from datetime import datetime
import os

class FunctionPlotterGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Function Plotter")
        self.root.geometry("1400x900")
        self.root.configure(bg='#f0f0f0')
        
        # Configuration
        self.max_poly_terms = 11
        self.max_fourier_terms = 9
        
        # Default state
        self.method = 1
        self.input_mode = "text"
        self.dc = 0.0
        self.f0 = 1.0
        
        # Polynomial coefficients
        self.poly_coeffs = np.array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1], dtype=float)
        
        # Fourier coefficients
        self.fourier_amps_a = np.array([0, 0, 0, 0, 0, 0, 0, 0, 0], dtype=float)
        self.fourier_amps_b = np.array([1, 0, 0, 0, 0, 0, 0, 0, 0], dtype=float)
        
        # Time parameters
        self.t_start = -1.0
        self.t_end = 1.0
        self.dt = 0.01
        self.times_user_set = False
        
        self.create_ui()
        self.update_controls()
        self.update_plots()
    
    def create_ui(self):
        """Create the user interface"""
        # Main frame
        main_frame = tk.Frame(self.root, bg='#f0f0f0')
        main_frame.pack(fill='both', expand=True, padx=3, pady=3)
        
        # LEFT PANEL
        left_frame = tk.Frame(main_frame, bg='#f0f0f0', width=280)
        left_frame.pack(side='left', fill='both', expand=False, padx=0, pady=0)
        
        # Title
        title_label = tk.Label(left_frame, text="Function Plotter", 
                              font=("Arial", 12, "bold"), bg='#f0f0f0', fg='#2c3e50')
        title_label.pack(pady=3)
        
        # Method selection
        type_frame = tk.LabelFrame(left_frame, text="Method", bg='#f0f0f0', font=("Arial", 8))
        type_frame.pack(fill='x', padx=2, pady=2)
        
        self.method_var = tk.IntVar(value=1)
        ttk.Radiobutton(type_frame, text="Polynomial", variable=self.method_var, 
                       value=1, command=self.on_method_change).pack(anchor='w', padx=3)
        ttk.Radiobutton(type_frame, text="Fourier", variable=self.method_var, 
                       value=2, command=self.on_method_change).pack(anchor='w', padx=3)
        
        # Mode selection
        mode_frame = tk.LabelFrame(left_frame, text="Mode", bg='#f0f0f0', font=("Arial", 8))
        mode_frame.pack(fill='x', padx=2, pady=2)
        
        self.mode_var = tk.StringVar(value="text")
        ttk.Radiobutton(mode_frame, text="Text", variable=self.mode_var, 
                       value="text", command=self.on_mode_change).pack(anchor='w', padx=3)
        ttk.Radiobutton(mode_frame, text="Sliders", variable=self.mode_var, 
                       value="slider", command=self.on_mode_change).pack(anchor='w', padx=3)
        
        # Buttons
        button_frame = tk.Frame(left_frame, bg='#f0f0f0')
        button_frame.pack(fill='x', padx=2, pady=2)
        ttk.Button(button_frame, text="Transform", command=self.transform_callback, width=9).pack(side='left', padx=1)
        ttk.Button(button_frame, text="Reset", command=self.reset_callback, width=9).pack(side='left', padx=1)
        ttk.Button(button_frame, text="Export", command=self.export_callback, width=7).pack(side='left', padx=1)
        
        # Polynomial
        poly_frame = tk.LabelFrame(left_frame, text="Polynomial", bg='#d9e5f0', font=("Arial", 8))
        poly_frame.pack(fill='both', expand=False, padx=2, pady=2)
        
        self.poly_canvas = tk.Canvas(poly_frame, bg='#f0f0f0', height=60, highlightthickness=0, relief='flat')
        poly_scroll = ttk.Scrollbar(poly_frame, orient='vertical', command=self.poly_canvas.yview)
        self.poly_frame_inner = tk.Frame(self.poly_canvas, bg='#f0f0f0')
        
        self.poly_frame_inner.bind(
            "<Configure>",
            lambda e: self.poly_canvas.configure(scrollregion=self.poly_canvas.bbox("all"))
        )
        
        self.poly_canvas.create_window((0, 0), window=self.poly_frame_inner, anchor="nw")
        self.poly_canvas.configure(yscrollcommand=poly_scroll.set)
        self.poly_canvas.pack(side='left', fill='both', expand=True, padx=1, pady=1)
        poly_scroll.pack(side='right', fill='y')
        
        self.poly_inputs = []
        
        # Fourier
        fourier_frame = tk.LabelFrame(left_frame, text="Fourier", bg='#f0e5d9', font=("Arial", 8))
        fourier_frame.pack(fill='x', padx=2, pady=2)
        
        f0_frame = tk.Frame(fourier_frame, bg='#f0e5d9')
        f0_frame.pack(fill='x', padx=1, pady=1)
        tk.Label(f0_frame, text="f0:", bg='#f0e5d9', width=5, font=("Arial", 7)).pack(side='left')
        self.f0_entry = tk.Entry(f0_frame, width=8, font=("Arial", 7))
        self.f0_entry.insert(0, "1.0")
        self.f0_entry.pack(side='left', padx=2)
        self.f0_entry.bind('<KeyRelease>', lambda e: self.on_fourier_param_change())
        
        dc_frame = tk.Frame(fourier_frame, bg='#f0e5d9')
        dc_frame.pack(fill='x', padx=1, pady=1)
        tk.Label(dc_frame, text="DC:", bg='#f0e5d9', width=5, font=("Arial", 7)).pack(side='left')
        self.dc_entry = tk.Entry(dc_frame, width=8, font=("Arial", 7))
        self.dc_entry.insert(0, "0.0")
        self.dc_entry.pack(side='left', padx=2)
        self.dc_entry.bind('<KeyRelease>', lambda e: self.on_fourier_param_change())
        
        tk.Label(fourier_frame, text="a (cos)", font=("Arial", 7, "bold"), bg='#f0e5d9').pack(padx=1, pady=0)
        self.fourier_a_frame = tk.Frame(fourier_frame, bg='#f0e5d9')
        self.fourier_a_frame.pack(fill='x', padx=1, pady=0)
        self.fourier_a_inputs = []
        
        tk.Label(fourier_frame, text="b (sin)", font=("Arial", 7, "bold"), bg='#f0e5d9').pack(padx=1, pady=0)
        self.fourier_b_frame = tk.Frame(fourier_frame, bg='#f0e5d9')
        self.fourier_b_frame.pack(fill='x', padx=1, pady=0)
        self.fourier_b_inputs = []
        
        # Time
        time_frame = tk.LabelFrame(left_frame, text="Time", bg='#f0f0f0', font=("Arial", 8))
        time_frame.pack(fill='x', padx=2, pady=2)
        
        t_start_frame = tk.Frame(time_frame, bg='#f0f0f0')
        t_start_frame.pack(fill='x', padx=1, pady=0)
        tk.Label(t_start_frame, text="Start:", bg='#f0f0f0', width=5, font=("Arial", 7)).pack(side='left')
        self.t_start_entry = tk.Entry(t_start_frame, width=10, font=("Arial", 7))
        self.t_start_entry.insert(0, "-1.0")
        self.t_start_entry.pack(side='left', padx=1)
        self.t_start_entry.bind('<KeyRelease>', lambda e: self.on_time_change())
        
        t_end_frame = tk.Frame(time_frame, bg='#f0f0f0')
        t_end_frame.pack(fill='x', padx=1, pady=0)
        tk.Label(t_end_frame, text="End:", bg='#f0f0f0', width=5, font=("Arial", 7)).pack(side='left')
        self.t_end_entry = tk.Entry(t_end_frame, width=10, font=("Arial", 7))
        self.t_end_entry.insert(0, "1.0")
        self.t_end_entry.pack(side='left', padx=1)
        self.t_end_entry.bind('<KeyRelease>', lambda e: self.on_time_change())
        
        dt_frame = tk.Frame(time_frame, bg='#f0f0f0')
        dt_frame.pack(fill='x', padx=1, pady=0)
        tk.Label(dt_frame, text="dt:", bg='#f0f0f0', width=5, font=("Arial", 7)).pack(side='left')
        self.dt_entry = tk.Entry(dt_frame, width=10, font=("Arial", 7))
        self.dt_entry.insert(0, "0.01")
        self.dt_entry.pack(side='left', padx=1)
        self.dt_entry.bind('<KeyRelease>', lambda e: self.on_time_change())
        
        # Info
        info_frame = tk.LabelFrame(left_frame, text="Info", bg='#f0f0f0', font=("Arial", 8))
        info_frame.pack(fill='both', expand=True, padx=2, pady=2)
        
        self.info_text = tk.Text(info_frame, height=4, width=32, font=("Courier", 6), 
                                bg='#fffef0', relief='solid', borderwidth=1)
        self.info_text.pack(fill='both', expand=True, padx=1, pady=1)
        self.info_text.config(state='disabled')
        
        # RIGHT PANEL - PLOT
        right_frame = tk.Frame(main_frame, bg='white')
        right_frame.pack(side='right', fill='both', expand=True, padx=0, pady=0)
        
        self.figure = Figure(figsize=(8, 6), dpi=100)
        self.canvas = FigureCanvasTkAgg(self.figure, master=right_frame)
        self.canvas.get_tk_widget().pack(fill='both', expand=True)
    
    def on_method_change(self):
        self.method = self.method_var.get()
        self.update_controls()
        self.update_plots()
    
    def on_mode_change(self):
        self.input_mode = self.mode_var.get()
        self.update_controls()
    
    def on_fourier_param_change(self):
        try:
            self.f0 = float(self.f0_entry.get())
            self.dc = float(self.dc_entry.get())
            if not self.times_user_set:
                self.t_start = -1.0 / self.f0
                self.t_end = 1.0 / self.f0
                self.t_start_entry.delete(0, tk.END)
                self.t_start_entry.insert(0, f"{self.t_start:.3f}")
                self.t_end_entry.delete(0, tk.END)
                self.t_end_entry.insert(0, f"{self.t_end:.3f}")
            self.update_plots()
            self.update_info()
        except ValueError:
            pass
    
    def on_time_change(self):
        try:
            self.t_start = float(self.t_start_entry.get())
            self.t_end = float(self.t_end_entry.get())
            self.dt = float(self.dt_entry.get())
            self.times_user_set = True
            self.update_plots()
        except ValueError:
            pass
    
    def on_coeff_change(self, idx):
        def callback(*args):
            try:
                if self.method == 1:
                    self.poly_coeffs[idx] = float(self.poly_inputs[idx].get())
                self.update_plots()
                self.update_info()
            except ValueError:
                pass
        return callback
    
    def on_fourier_a_change(self, idx):
        def callback(*args):
            try:
                self.fourier_amps_a[idx] = float(self.fourier_a_inputs[idx].get())
                self.update_plots()
                self.update_info()
            except ValueError:
                pass
        return callback
    
    def on_fourier_b_change(self, idx):
        def callback(*args):
            try:
                self.fourier_amps_b[idx] = float(self.fourier_b_inputs[idx].get())
                self.update_plots()
                self.update_info()
            except ValueError:
                pass
        return callback
    
    def update_controls(self):
        # Clear polynomial
        for widget in self.poly_frame_inner.winfo_children():
            widget.destroy()
        self.poly_inputs = []
        
        for i in range(self.max_poly_terms + 1):
            power = self.max_poly_terms - i
            frame = tk.Frame(self.poly_frame_inner, bg='#f0f0f0')
            frame.pack(fill='x', padx=1, pady=0)
            
            tk.Label(frame, text=f"a{power}:", bg='#f0f0f0', width=3, font=("Arial", 6)).pack(side='left')
            
            entry = tk.Entry(frame, width=7, font=("Arial", 6))
            entry.insert(0, f"{self.poly_coeffs[i]:.2f}")
            entry.pack(side='left', padx=1)
            entry.bind('<KeyRelease>', self.on_coeff_change(i))
            self.poly_inputs.append(entry)
            
            if self.input_mode == "slider":
                slider = ttk.Scale(frame, from_=-5, to=5, orient='horizontal', 
                                  command=lambda val, idx=i: self.on_slider_poly_change(idx, val))
                slider.set(self.poly_coeffs[i])
                slider.pack(side='left', fill='x', expand=True, padx=1)
        
        # Clear Fourier A
        for widget in self.fourier_a_frame.winfo_children():
            widget.destroy()
        self.fourier_a_inputs = []
        
        row_a = tk.Frame(self.fourier_a_frame, bg='#f0e5d9')
        row_a.pack(fill='x', padx=0)
        
        for i in range(self.max_fourier_terms):
            frame = tk.Frame(row_a, bg='#f0e5d9')
            frame.pack(side='left', padx=0, pady=0)
            
            entry = tk.Entry(frame, width=4, font=("Arial", 6))
            entry.insert(0, f"{self.fourier_amps_a[i]:.1f}")
            entry.pack()
            entry.bind('<KeyRelease>', self.on_fourier_a_change(i))
            self.fourier_a_inputs.append(entry)
        
        # Clear Fourier B
        for widget in self.fourier_b_frame.winfo_children():
            widget.destroy()
        self.fourier_b_inputs = []
        
        row_b = tk.Frame(self.fourier_b_frame, bg='#f0e5d9')
        row_b.pack(fill='x', padx=0)
        
        for i in range(self.max_fourier_terms):
            frame = tk.Frame(row_b, bg='#f0e5d9')
            frame.pack(side='left', padx=0, pady=0)
            
            entry = tk.Entry(frame, width=4, font=("Arial", 6))
            entry.insert(0, f"{self.fourier_amps_b[i]:.1f}")
            entry.pack()
            entry.bind('<KeyRelease>', self.on_fourier_b_change(i))
            self.fourier_b_inputs.append(entry)
    
    def on_slider_poly_change(self, idx, val):
        try:
            self.poly_coeffs[idx] = float(val)
            self.poly_inputs[idx].delete(0, tk.END)
            self.poly_inputs[idx].insert(0, f"{float(val):.2f}")
            self.update_plots()
            self.update_info()
        except (ValueError, IndexError):
            pass
    
    def evaluate_polynomial(self, t):
        result = np.zeros_like(t, dtype=float)
        for i, coeff in enumerate(self.poly_coeffs):
            power = self.max_poly_terms - i
            result += coeff * (t ** power)
        return result
    
    def evaluate_fourier(self, t):
        result = self.dc * np.ones_like(t, dtype=float)
        for n in range(1, self.max_fourier_terms + 1):
            omega = 2 * np.pi * n * self.f0
            result += self.fourier_amps_a[n-1] * np.cos(omega * t)
            result += self.fourier_amps_b[n-1] * np.sin(omega * t)
        return result
    
    def compute_fourier_from_poly(self):
        t_sample = np.arange(self.t_start, self.t_end, self.dt)
        y = self.evaluate_polynomial(t_sample)
        
        y_fft = fftpack.fft(y)
        n_samples = len(t_sample)
        freqs = fftpack.fftfreq(n_samples, self.dt)
        
        self.fourier_amps_a[:] = 0
        self.fourier_amps_b[:] = 0
        
        for n in range(1, min(self.max_fourier_terms + 1, len(freqs) // 2)):
            target_freq = n * self.f0
            idx = np.argmin(np.abs(freqs - target_freq))
            
            if idx < len(y_fft):
                coeff = y_fft[idx]
                magnitude = 2 * np.abs(coeff) / n_samples
                phase = np.angle(coeff)
                
                self.fourier_amps_a[n-1] = magnitude * np.cos(phase)
                self.fourier_amps_b[n-1] = magnitude * np.sin(phase)
    
    def update_plots(self):
        try:
            t = np.arange(self.t_start, self.t_end, self.dt)
            
            if self.method == 1:
                y = self.evaluate_polynomial(t)
                title = "Polynomial"
            else:
                y = self.evaluate_fourier(t)
                title = "Fourier Series"
            
            self.figure.clear()
            ax = self.figure.add_subplot(111)
            ax.plot(t, y, 'b-', linewidth=2)
            ax.grid(True, alpha=0.3)
            ax.set_xlabel('Time (s)', fontsize=9)
            ax.set_ylabel('Amplitude', fontsize=9)
            ax.set_title(title, fontsize=10, fontweight='bold')
            
            self.figure.tight_layout()
            self.canvas.draw()
        except Exception as e:
            print(f"Error updating plot: {e}")
    
    def update_info(self):
        try:
            if self.method == 1:
                info = "Polynomial\n"
            else:
                info = f"Fourier\nf0={self.f0:.2f}\nDC={self.dc:.2f}\n"
            
            info += f"t=[{self.t_start:.2f},{self.t_end:.2f}]\ndt={self.dt:.3f}"
            
            self.info_text.config(state='normal')
            self.info_text.delete(1.0, tk.END)
            self.info_text.insert(1.0, info)
            self.info_text.config(state='disabled')
        except Exception as e:
            print(f"Error updating info: {e}")
    
    def transform_callback(self):
        if self.method == 1:
            self.compute_fourier_from_poly()
            self.method = 2
            self.method_var.set(2)
            self.update_controls()
            self.update_plots()
            self.update_info()
    
    def reset_callback(self):
        self.method = 1
        self.method_var.set(1)
        self.dc = 0.0
        self.f0 = 1.0
        self.poly_coeffs = np.array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1], dtype=float)
        self.fourier_amps_a = np.array([0, 0, 0, 0, 0, 0, 0, 0, 0], dtype=float)
        self.fourier_amps_b = np.array([1, 0, 0, 0, 0, 0, 0, 0, 0], dtype=float)
        self.t_start = -1.0
        self.t_end = 1.0
        self.dt = 0.01
        self.times_user_set = False
        
        self.f0_entry.delete(0, tk.END)
        self.f0_entry.insert(0, "1.0")
        self.dc_entry.delete(0, tk.END)
        self.dc_entry.insert(0, "0.0")
        self.t_start_entry.delete(0, tk.END)
        self.t_start_entry.insert(0, "-1.0")
        self.t_end_entry.delete(0, tk.END)
        self.t_end_entry.insert(0, "1.0")
        self.dt_entry.delete(0, tk.END)
        self.dt_entry.insert(0, "0.01")
        
        self.update_controls()
        self.update_plots()
        self.update_info()
    
    def export_callback(self):
        try:
            t = np.arange(self.t_start, self.t_end, self.dt)
            
            if self.method == 1:
                y = self.evaluate_polynomial(t)
                func_type = "polynomial"
            else:
                y = self.evaluate_fourier(t)
                func_type = "fourier"
            
            fig = Figure(figsize=(10, 6), dpi=150)
            ax = fig.add_subplot(111)
            ax.plot(t, y, 'b-', linewidth=2)
            ax.grid(True, alpha=0.3)
            ax.set_xlabel('Time (s)', fontsize=11)
            ax.set_ylabel('Amplitude', fontsize=11)
            ax.set_title(f'Function Plotter - {func_type.title()}', fontsize=12, fontweight='bold')
            
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"{func_type}_{timestamp}.png"
            
            fig.savefig(filename, dpi=150, bbox_inches='tight')
            plt.close(fig)
            print(f"Figure saved to: {filename}")
        except Exception as e:
            print(f"Error exporting plot: {e}")


def main():
    root = tk.Tk()
    app = FunctionPlotterGUI(root)
    root.mainloop()


if __name__ == '__main__':
    main()
