#!/usr/bin/env python3
"""
Function Plotter - Flet Web Application
Cross-platform app built with Flet for polynomial and Fourier function visualization

Run with: flet run function_plotter_flet.py
Run web: flet run --web function_plotter_flet.py
"""

import flet as ft
import numpy as np
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')
from matplotlib.figure import Figure
from io import BytesIO
import base64
from scipy import fftpack
from datetime import datetime
import os

class FunctionPlotterApp(ft.UserControl):
    def build(self):
        # Configuration
        self.max_poly_terms = 11        # a0 to a11 (12 coefficients)
        self.max_fourier_terms = 9      # a1-a9, b1-b9
        
        # Default state
        self.method = 1                 # 1 = polynomial, 2 = Fourier
        self.input_mode = "text"        # "text" or "slider"
        self.dc = 0.0
        self.f0 = 1.0
        
        # Polynomial coefficients (a11, a10, ..., a1, a0)
        self.poly_coeffs = np.array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1], dtype=float)
        
        # Fourier coefficients
        self.fourier_amps_a = np.array([0, 0, 0, 0, 0, 0, 0, 0, 0], dtype=float)
        self.fourier_amps_b = np.array([1, 0, 0, 0, 0, 0, 0, 0, 0], dtype=float)
        
        # Time parameters
        self.t_start = -1.0
        self.t_end = 1.0
        self.dt = 0.01
        self.times_user_set = False
        
        # UI storage
        self.poly_coeff_inputs = []
        self.fourier_a_inputs = []
        self.fourier_b_inputs = []
        
        # Main layout
        self.left_panel = ft.Container(
            content=ft.Column(
                [
                    ft.Text("Function Plotter", 
                           size=20, weight="bold", color="#2c3e50"),
                    ft.Divider(),
                    
                    # Input type selection
                    ft.Row([
                        ft.Text("Input type:", weight="bold"),
                        ft.RadioGroup(
                            value="1",
                            on_change=self.on_method_change,
                            content=ft.Row([
                                ft.Radio(value="1", label="Polynomial"),
                                ft.Radio(value="2", label="Fourier"),
                            ], spacing=10)
                        )
                    ], spacing=10),
                    
                    # Input mode selection
                    ft.Row([
                        ft.Text("Input mode:", weight="bold"),
                        ft.RadioGroup(
                            value="text",
                            on_change=self.on_mode_change,
                            content=ft.Row([
                                ft.Radio(value="text", label="Text"),
                                ft.Radio(value="slider", label="Sliders"),
                            ], spacing=10)
                        )
                    ], spacing=10),
                    
                    ft.Divider(),
                    
                    # Buttons
                    ft.Row([
                        ft.ElevatedButton("Transform", on_click=self.transform_callback, expand=True),
                        ft.ElevatedButton("Export", on_click=self.export_callback, expand=True),
                    ], spacing=5),
                    
                    ft.Row([
                        ft.ElevatedButton("Reset", on_click=self.reset_callback, expand=True),
                    ], spacing=5),
                    
                    ft.Divider(),
                    
                    # Polynomial section
                    ft.Container(
                        content=ft.Text("POLYNOMIAL COEFFICIENTS", weight="bold", color="#333366"),
                        bgcolor="#d9e5f0",
                        padding=8,
                        border_radius=5,
                        ref=ft.Ref()
                    ),
                    
                    ft.Container(
                        content=ft.Column([], scroll="auto"),
                        height=280,
                        ref=ft.Ref()
                    ),
                    
                    ft.Divider(),
                    
                    # Fourier section
                    ft.Container(
                        content=ft.Text("FOURIER PARAMETERS", weight="bold", color="#663333"),
                        bgcolor="#f0e5d9",
                        padding=8,
                        border_radius=5,
                        ref=ft.Ref()
                    ),
                    
                    # Fourier frequency and DC
                    ft.Row([
                        ft.TextField(label="Base frequency f0 (Hz)", value="1.0", width=150,
                                    on_change=self.on_f0_change, ref=ft.Ref()),
                        ft.TextField(label="DC offset (a0/2)", value="0.0", width=150,
                                    on_change=self.on_dc_change, ref=ft.Ref()),
                    ], spacing=10),
                    
                    # Fourier A coefficients
                    ft.Text("Cosine coefficients (a1-a9)", size=10, weight="bold", color="#444"),
                    ft.Container(
                        content=ft.Column([], scroll="auto"),
                        height=120,
                        ref=ft.Ref()
                    ),
                    
                    # Fourier B coefficients
                    ft.Text("Sine coefficients (b1-b9)", size=10, weight="bold", color="#444"),
                    ft.Container(
                        content=ft.Column([], scroll="auto"),
                        height=120,
                        ref=ft.Ref()
                    ),
                    
                    ft.Divider(),
                    
                    # Time parameters
                    ft.Text("Time Parameters", size=11, weight="bold"),
                    ft.Row([
                        ft.TextField(label="Start time (s)", value="-1.0", width=120,
                                    on_change=self.on_time_change, ref=ft.Ref()),
                        ft.TextField(label="End time (s)", value="1.0", width=120,
                                    on_change=self.on_time_change, ref=ft.Ref()),
                        ft.TextField(label="Time step (s)", value="0.01", width=120,
                                    on_change=self.on_time_change, ref=ft.Ref()),
                    ], spacing=5),
                    
                    ft.Divider(),
                    
                    # Info display
                    ft.Container(
                        content=ft.Text("System Info", size=10, family="monospace"),
                        bgcolor="#fffef0",
                        padding=8,
                        border_radius=3,
                        height=80,
                        ref=ft.Ref()
                    ),
                ],
                spacing=8,
                scroll="auto"
            ),
            padding=10,
            width=300,
            bgcolor="#f0f0f0"
        )
        
        # Store references
        self.poly_container = self.left_panel.content.controls[13].content
        self.fourier_f0_field = self.left_panel.content.controls[18].controls[0]
        self.fourier_dc_field = self.left_panel.content.controls[18].controls[1]
        self.fourier_a_container = self.left_panel.content.controls[21].content
        self.fourier_b_container = self.left_panel.content.controls[23].content
        self.time_fields = self.left_panel.content.controls[25].controls
        self.info_container = self.left_panel.content.controls[28]
        
        # Right panel for plot
        self.plot_image = ft.Image(expand=True, fit="contain")
        self.right_panel = ft.Container(
            content=self.plot_image,
            expand=True,
            bgcolor="white"
        )
        
        # Main layout
        main = ft.Row([
            self.left_panel,
            self.right_panel
        ], expand=True, spacing=0)
        
        # Initialize controls
        self.update_controls()
        self.update_plots()
        
        return main
    
    def on_method_change(self, e):
        """Handle method change (polynomial vs Fourier)"""
        self.method = int(e.control.value)
        self.update_controls()
        self.update_plots()
    
    def on_mode_change(self, e):
        """Handle input mode change"""
        self.input_mode = e.control.value
        self.update_controls()
    
    def on_f0_change(self, e):
        """Handle base frequency change"""
        try:
            self.f0 = float(e.control.value)
            if not self.times_user_set:
                self.t_start = -1.0 / self.f0
                self.t_end = 1.0 / self.f0
                self.time_fields[0].value = f"{self.t_start:.4f}"
                self.time_fields[1].value = f"{self.t_end:.4f}"
            self.update_plots()
        except ValueError:
            pass
    
    def on_dc_change(self, e):
        """Handle DC offset change"""
        try:
            self.dc = float(e.control.value)
            self.update_plots()
        except ValueError:
            pass
    
    def on_time_change(self, e):
        """Handle time parameter change"""
        try:
            self.t_start = float(self.time_fields[0].value)
            self.t_end = float(self.time_fields[1].value)
            self.dt = float(self.time_fields[2].value)
            self.times_user_set = True
            self.update_plots()
        except ValueError:
            pass
    
    def on_coeff_change(self, idx):
        """Create callback for coefficient change"""
        def callback(e):
            try:
                if self.method == 1:
                    self.poly_coeffs[idx] = float(e.control.value)
                self.update_plots()
            except ValueError:
                pass
        return callback
    
    def on_fourier_a_change(self, idx):
        """Create callback for Fourier A coefficient change"""
        def callback(e):
            try:
                self.fourier_amps_a[idx] = float(e.control.value)
                self.update_plots()
            except ValueError:
                pass
        return callback
    
    def on_fourier_b_change(self, idx):
        """Create callback for Fourier B coefficient change"""
        def callback(e):
            try:
                self.fourier_amps_b[idx] = float(e.control.value)
                self.update_plots()
            except ValueError:
                pass
        return callback
    
    def update_controls(self):
        """Update UI controls based on current state"""
        # Clear and rebuild polynomial controls
        self.poly_coeff_inputs = []
        self.poly_container.controls.clear()
        
        for i in range(self.max_poly_terms + 1):
            power = self.max_poly_terms - i
            row = ft.Row([
                ft.Text(f"a{power}:", width=30),
                ft.TextField(
                    value=f"{self.poly_coeffs[i]:.4f}",
                    width=60,
                    on_change=self.on_coeff_change(i)
                ),
            ] + (
                [ft.Slider(min=-10, max=10, value=self.poly_coeffs[i], 
                          on_change=self.on_coeff_change(i), expand=True)]
                if self.input_mode == "slider" else []
            ), spacing=5)
            self.poly_container.controls.append(row)
            self.poly_coeff_inputs.append(row.controls[1])
        
        # Clear and rebuild Fourier A controls
        self.fourier_a_inputs = []
        self.fourier_a_container.controls.clear()
        
        row_a = ft.Row(spacing=5)
        for i in range(self.max_fourier_terms):
            col = ft.Column([
                ft.Text(f"a{i+1}", size=9, text_align="center"),
                ft.TextField(
                    value=f"{self.fourier_amps_a[i]:.2f}",
                    width=50,
                    text_align="center",
                    on_change=self.on_fourier_a_change(i)
                ),
            ], spacing=2, horizontal_alignment="center")
            row_a.controls.append(col)
            self.fourier_a_inputs.append(col.controls[1])
        self.fourier_a_container.controls.append(row_a)
        
        # Clear and rebuild Fourier B controls
        self.fourier_b_inputs = []
        self.fourier_b_container.controls.clear()
        
        row_b = ft.Row(spacing=5)
        for i in range(self.max_fourier_terms):
            col = ft.Column([
                ft.Text(f"b{i+1}", size=9, text_align="center"),
                ft.TextField(
                    value=f"{self.fourier_amps_b[i]:.2f}",
                    width=50,
                    text_align="center",
                    on_change=self.on_fourier_b_change(i)
                ),
            ], spacing=2, horizontal_alignment="center")
            row_b.controls.append(col)
            self.fourier_b_inputs.append(col.controls[1])
        self.fourier_b_container.controls.append(row_b)
    
    def evaluate_polynomial(self, t):
        """Evaluate polynomial at time points"""
        result = np.zeros_like(t, dtype=float)
        for i, coeff in enumerate(self.poly_coeffs):
            power = self.max_poly_terms - i
            result += coeff * (t ** power)
        return result
    
    def evaluate_fourier(self, t):
        """Evaluate Fourier series at time points"""
        result = self.dc * np.ones_like(t, dtype=float)
        for n in range(1, self.max_fourier_terms + 1):
            omega = 2 * np.pi * n * self.f0
            result += self.fourier_amps_a[n-1] * np.cos(omega * t)
            result += self.fourier_amps_b[n-1] * np.sin(omega * t)
        return result
    
    def compute_fourier_from_poly(self):
        """Compute Fourier coefficients from polynomial"""
        t_sample = np.arange(self.t_start, self.t_end, self.dt)
        y = self.evaluate_polynomial(t_sample)
        
        # Compute FFT
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
    
    def get_plot_image(self):
        """Generate plot image and return as base64"""
        t = np.arange(self.t_start, self.t_end, self.dt)
        
        if self.method == 1:
            y = self.evaluate_polynomial(t)
            title = "Polynomial"
        else:
            y = self.evaluate_fourier(t)
            title = "Fourier Series"
        
        fig = Figure(figsize=(8, 5), dpi=100)
        ax = fig.add_subplot(111)
        ax.plot(t, y, 'b-', linewidth=2)
        ax.grid(True, alpha=0.3)
        ax.set_xlabel('Time (s)')
        ax.set_ylabel('Amplitude')
        ax.set_title(f'Function Plotter - {title}')
        
        # Save to bytes
        buf = BytesIO()
        fig.savefig(buf, format='png', bbox_inches='tight')
        buf.seek(0)
        
        # Convert to base64
        img_base64 = base64.b64encode(buf.read()).decode()
        plt.close(fig)
        
        return f"data:image/png;base64,{img_base64}"
    
    def update_plots(self):
        """Update plot display"""
        try:
            self.plot_image.src = self.get_plot_image()
            self.page.update()
        except Exception as e:
            print(f"Error updating plot: {e}")
    
    def get_info_string(self):
        """Generate info string"""
        if self.method == 1:
            info = f"Polynomial | f0: {self.f0:.3f} Hz\nt: [{self.t_start:.3f}, {self.t_end:.3f}] dt: {self.dt:.3f}"
        else:
            info = f"Fourier | f0: {self.f0:.3f} Hz | DC: {self.dc:.3f}\nt: [{self.t_start:.3f}, {self.t_end:.3f}]"
        
        return info
    
    def transform_callback(self, e):
        """Handle transform button"""
        if self.method == 1:
            self.compute_fourier_from_poly()
            self.method = 2
            self.update_controls()
            self.update_plots()
    
    def reset_callback(self, e):
        """Handle reset button"""
        self.method = 1
        self.dc = 0.0
        self.f0 = 1.0
        self.poly_coeffs = np.array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1], dtype=float)
        self.fourier_amps_a = np.array([0, 0, 0, 0, 0, 0, 0, 0, 0], dtype=float)
        self.fourier_amps_b = np.array([1, 0, 0, 0, 0, 0, 0, 0, 0], dtype=float)
        self.t_start = -1.0
        self.t_end = 1.0
        self.dt = 0.01
        self.times_user_set = False
        self.fourier_f0_field.value = "1.0"
        self.fourier_dc_field.value = "0.0"
        self.update_controls()
        self.update_plots()
    
    def export_callback(self, e):
        """Handle export button"""
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


def main(page: ft.Page):
    page.title = "Function Plotter"
    page.window.width = 1400
    page.window.height = 900
    
    app = FunctionPlotterApp()
    app.page = page
    
    page.add(app)


if __name__ == '__main__':
    ft.app(main, view=ft.AppView.WEB_BROWSER)
