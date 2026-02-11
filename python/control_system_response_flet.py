#!/usr/bin/env python3
"""
Control System Response Analyser - Flet Web Application
Cross-platform app built with Flet

Run with: flet run control_system_webapp.py
Run web: flet run --web control_system_webapp.py
"""

import flet as ft
import numpy as np
import matplotlib.pyplot as plt
from scipy import signal
from datetime import datetime
import io
import base64

class ControlSystemApp(ft.UserControl):
    def build(self):
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
        
        self.define_parameters()
        self.current_plant = 0
        self.current_controller = 0
        self.plant_sliders = []
        self.controller_sliders = []
        
        # Main layout
        self.left_panel = ft.Container(
            content=ft.Column(
                [
                    # Title
                    ft.Text("Control System Response", 
                           size=20, weight="bold", color="#2c3e50"),
                    ft.Divider(),
                    
                    # Mode selection
                    ft.Row([
                        ft.Text("Input Mode:", weight="bold"),
                    ]),
                    
                    # Buttons
                    ft.Row([
                        ft.ElevatedButton("Reset", on_click=self.reset_callback, expand=True),
                        ft.ElevatedButton("Export", on_click=self.export_callback, expand=True),
                    ], spacing=5),
                    
                    ft.Divider(),
                    
                    # Plant section
                    ft.Container(
                        content=ft.Text("PLANT", weight="bold", color="#333366"),
                        bgcolor="#d9e5f0",
                        padding=8,
                        border_radius=5
                    ),
                    
                    # Plant dropdown
                    ft.Dropdown(
                        label="Plant Model",
                        options=[ft.dropdown.Option(model) for model in self.plant_models],
                        value=self.plant_models[0],
                        on_change=self.on_plant_change,
                        expand=True
                    ),
                    
                    # State-space note (hidden initially)
                    ft.Container(
                        content=ft.Text("State Space: B=[0;1], C=[1,0], D=0",
                                       size=10, color="#666699"),
                        bgcolor="#f0f0ff",
                        padding=5,
                        border_radius=3,
                        visible=False,
                        ref=ft.Ref()
                    ),
                    
                    # Plant parameters container
                    ft.Container(
                        content=ft.Column([], scroll="auto"),
                        height=300,
                        ref=ft.Ref()
                    ),
                    
                    ft.Divider(),
                    
                    # Controller section
                    ft.Container(
                        content=ft.Text("CONTROLLER", weight="bold", color="#663333"),
                        bgcolor="#f0e5d9",
                        padding=8,
                        border_radius=5
                    ),
                    
                    # Controller dropdown
                    ft.Dropdown(
                        label="Controller Type",
                        options=[ft.dropdown.Option(ct) for ct in self.controller_types],
                        value=self.controller_types[0],
                        on_change=self.on_controller_change,
                        expand=True
                    ),
                    
                    # Controller parameters container
                    ft.Container(
                        content=ft.Column([], scroll="auto"),
                        height=200,
                        ref=ft.Ref()
                    ),
                    
                    # Info panel
                    ft.Container(
                        content=ft.Text("System Info", size=10, family="monospace"),
                        bgcolor="#fffef0",
                        padding=8,
                        border_radius=3,
                        height=100,
                        ref=ft.Ref()
                    ),
                ],
                spacing=8,
                scroll="auto"
            ),
            padding=10,
            width=280,
            bgcolor="#f0f0f0"
        )
        
        # Store references
        self.plant_params_container = self.left_panel.content.controls[10].content
        self.controller_params_container = self.left_panel.content.controls[16].content
        self.ss_note_container = self.left_panel.content.controls[9]
        self.info_container = self.left_panel.content.controls[17]
        
        # Right panel for plots
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
        
        # Update initial controls
        self.update_controls()
        self.update_plots()
        
        return main
    
    def define_parameters(self):
        """Define parameter structures for all models"""
        self.params_method1 = [
            {'name': 'Time Constant (τ)', 'label': 'τ', 'min': 0.1, 'max': 10.0, 'init': 1.0, 'step': 0.1},
            {'name': 'DC Gain (K)', 'label': 'K', 'min': 0.1, 'max': 10.0, 'init': 1.0, 'step': 0.1}
        ]
        
        self.params_method2 = [
            {'name': 'Natural Frequency (ωn)', 'label': 'ωn', 'min': 0.1, 'max': 50.0, 'init': 5.0, 'step': 0.5},
            {'name': 'Damping Ratio (ζ)', 'label': 'ζ', 'min': 0.01, 'max': 2.0, 'init': 0.7, 'step': 0.05},
            {'name': 'DC Gain (K)', 'label': 'K', 'min': 0.1, 'max': 10.0, 'init': 1.0, 'step': 0.1}
        ]
        
        self.params_method3 = [
            {'name': 'a2 (coefficient of y″)', 'label': 'a2', 'min': 0.0, 'max': 10.0, 'init': 1.0, 'step': 0.1},
            {'name': 'a1 (coefficient of y′)', 'label': 'a1', 'min': 0.0, 'max': 50.0, 'init': 7.0, 'step': 0.1},
            {'name': 'a0 (coefficient of y)', 'label': 'a0', 'min': 0.0, 'max': 500.0, 'init': 25.0, 'step': 0.5},
            {'name': 'b (coefficient of u)', 'label': 'b', 'min': 0.0, 'max': 100.0, 'init': 25.0, 'step': 0.5}
        ]
        
        self.params_method4 = [
            {'name': 'Numerator b0', 'label': 'b0', 'min': 0.0, 'max': 100.0, 'init': 25.0, 'step': 0.5},
            {'name': 'Denominator a2', 'label': 'a2', 'min': 0.01, 'max': 10.0, 'init': 1.0, 'step': 0.1},
            {'name': 'Denominator a1', 'label': 'a1', 'min': 0.0, 'max': 50.0, 'init': 7.0, 'step': 0.1},
            {'name': 'Denominator a0', 'label': 'a0', 'min': 0.0, 'max': 500.0, 'init': 25.0, 'step': 0.5}
        ]
        
        self.params_method5 = [
            {'name': 'A11 (state matrix)', 'label': 'A11', 'min': -50.0, 'max': 50.0, 'init': 0.0, 'step': 0.5},
            {'name': 'A12 (state matrix)', 'label': 'A12', 'min': -50.0, 'max': 50.0, 'init': 1.0, 'step': 0.5},
            {'name': 'A21 (state matrix)', 'label': 'A21', 'min': -50.0, 'max': 50.0, 'init': -25.0, 'step': 0.5},
            {'name': 'A22 (state matrix)', 'label': 'A22', 'min': -50.0, 'max': 50.0, 'init': -7.0, 'step': 0.5}
        ]
        
        self.params_pid = [
            {'name': 'Proportional Gain (Kp)', 'label': 'Kp', 'min': 0.0, 'max': 100.0, 'init': 1.0, 'step': 0.1},
            {'name': 'Integral Gain (Ki)', 'label': 'Ki', 'min': 0.0, 'max': 50.0, 'init': 0.0, 'step': 0.1},
            {'name': 'Derivative Gain (Kd)', 'label': 'Kd', 'min': 0.0, 'max': 20.0, 'init': 0.0, 'step': 0.1}
        ]
        
        self.params_statefb = [
            {'name': 'State Feedback Gain K1', 'label': 'K1', 'min': -100.0, 'max': 100.0, 'init': 1.0, 'step': 0.5},
            {'name': 'State Feedback Gain K2', 'label': 'K2', 'min': -100.0, 'max': 100.0, 'init': 1.0, 'step': 0.5}
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
    
    def update_controls(self):
        """Update parameter controls"""
        self.plant_params_container.controls.clear()
        self.controller_params_container.controls.clear()
        
        self.ss_note_container.visible = (self.current_plant == 4)
        
        params = self.all_params[self.current_plant]
        self.plant_sliders = []
        
        for i, param in enumerate(params):
            slider = ft.Slider(
                min=param['min'],
                max=param['max'],
                value=param['init'],
                divisions=int((param['max']-param['min'])/param['step']) if param['step'] > 0 else 100,
                label=f"{param['label']}: {param['init']:.1f}",
                on_change=lambda e, idx=i: self.on_plant_param_change(idx),
                expand=True
            )
            self.plant_sliders.append({'slider': slider, 'param': param})
            self.plant_params_container.controls.append(slider)
        
        if self.current_controller > 0:
            params = self.controller_params[self.current_controller]
            self.controller_sliders = []
            
            for i, param in enumerate(params):
                slider = ft.Slider(
                    min=param['min'],
                    max=param['max'],
                    value=param['init'],
                    divisions=int((param['max']-param['min'])/param['step']) if param['step'] > 0 else 100,
                    label=f"{param['label']}: {param['init']:.1f}",
                    on_change=lambda e, idx=i: self.on_controller_param_change(idx),
                    expand=True
                )
                self.controller_sliders.append({'slider': slider, 'param': param})
                self.controller_params_container.controls.append(slider)
        else:
            self.controller_sliders = []
        
        self.page.update()
    
    def get_plant_values(self):
        """Get current plant parameter values"""
        return [s['slider'].value for s in self.plant_sliders]
    
    def get_controller_values(self):
        """Get current controller parameter values"""
        return [s['slider'].value for s in self.controller_sliders]
    
    def on_plant_change(self, e):
        """Handle plant model change"""
        self.current_plant = self.plant_models.index(e.control.value)
        self.update_controls()
        self.update_plots()
    
    def on_controller_change(self, e):
        """Handle controller type change"""
        self.current_controller = self.controller_types.index(e.control.value)
        self.update_controls()
        self.update_plots()
    
    def on_plant_param_change(self, idx):
        """Handle plant parameter change"""
        slider = self.plant_sliders[idx]['slider']
        slider.label = f"{self.plant_sliders[idx]['param']['label']}: {slider.value:.1f}"
        self.page.update()
        self.update_plots()
    
    def on_controller_param_change(self, idx):
        """Handle controller parameter change"""
        slider = self.controller_sliders[idx]['slider']
        slider.label = f"{self.controller_sliders[idx]['param']['label']}: {slider.value:.1f}"
        self.page.update()
        self.update_plots()
    
    def convert_to_tf(self, values, method):
        """Convert plant parameters to transfer function"""
        if method == 0:
            tau, K = values
            tau = max(tau, 1e-6)
            num = [K]
            den = [tau, 1]
            wn = 1.0 / tau
            zeta = 1.0
            dc_gain = K
        elif method == 1:
            wn, zeta, K = values
            num = [K * wn**2]
            den = [1, 2*zeta*wn, wn**2]
            dc_gain = K
        elif method == 2:
            a2, a1, a0, b = values
            a2 = max(abs(a2), 1e-6)
            a0 = max(abs(a0), 1e-6)
            num = [max(b/a2, 1e-12)]
            den = [1, a1/a2, a0/a2]
            wn = np.sqrt(a0/a2) if a0/a2 > 0 else 1.0
            zeta = a1/(2*np.sqrt(a0*a2)) if a0*a2 > 0 else 1.0
            dc_gain = b/a0 if abs(a0) > 1e-12 else 1.0
        elif method == 3:
            b0, a2, a1, a0 = values
            a2 = max(abs(a2), 1e-6)
            a0 = max(abs(a0), 1e-6)
            num = [max(b0/a2, 1e-12)]
            den = [1, a1/a2, a0/a2]
            wn = np.sqrt(a0/a2) if a0/a2 > 0 else 1.0
            zeta = a1/(2*np.sqrt(a0*a2)) if a0*a2 > 0 else 1.0
            dc_gain = b0/a0 if abs(a0) > 1e-12 else 1.0
        elif method == 4:
            A11, A12, A21, A22 = values
            det_A = A11*A22 - A12*A21
            trace_A = A11 + A22
            num = [A12]
            den = [1, -trace_A, det_A]
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
        if self.current_controller == 0:
            return num_plant, den_plant
        elif self.current_controller == 1:
            Kp, Ki, Kd = controller_values
            num_c = [Kd, Kp, Ki]
            den_c = [1, 0]
            num_ol = np.convolve(num_c, num_plant)
            den_ol = np.convolve(den_c, den_plant)
            num_cl = num_ol
            den_cl = np.polyadd(den_ol, num_ol)
            return num_cl, den_cl
        elif self.current_controller == 2:
            plant_values = self.get_plant_values()
            if self.current_plant == 4 and len(plant_values) >= 4:
                A11, A12, A21, A22 = plant_values
                K1, K2 = controller_values
                A_cl = np.array([[A11, A12], [A21 - K1, A22 - K2]])
                det_Acl = np.linalg.det(A_cl)
                trace_Acl = np.trace(A_cl)
                den_cl = [1, -trace_Acl, det_Acl]
                num_cl = [0, 0, A_cl[0, 1]]
                if abs(A_cl[0, 1]) < 1e-12:
                    num_cl = [0, 0, 1e-6]
                return num_cl, den_cl
            else:
                K_eff = sum(controller_values)
                num_ol = K_eff * np.array(num_plant)
                den_ol = den_plant
                num_cl = num_ol
                den_cl = np.polyadd(den_ol, num_ol)
                return num_cl, den_cl
        
        return num_plant, den_plant
    
    def update_plots(self):
        """Update plots"""
        try:
            plant_values = self.get_plant_values()
            num_plant, den_plant, wn, zeta, K = self.convert_to_tf(plant_values, self.current_plant)
            
            controller_values = self.get_controller_values()
            num_cl, den_cl = self.compute_closed_loop(num_plant, den_plant, controller_values)
            
            if np.all(np.abs(num_cl) < 1e-12):
                num_cl = [1e-12]
            if np.all(np.abs(den_cl) < 1e-12):
                den_cl = [1, 1]
            
            sys_cl = signal.TransferFunction(num_cl, den_cl)
            poles_cl = np.roots(den_cl)
            
            max_real = np.max(np.real(poles_cl))
            if max_real < 0 and not np.isnan(max_real):
                T_settle = max(4.0 / abs(max_real), 1.0)
            else:
                T_settle = 10.0
            t = np.linspace(0, T_settle * 4, 1000)
            
            fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(10, 8))
            
            _, y_step = signal.step(sys_cl, T=t)
            ax1.plot(t, y_step, 'b-', linewidth=2.5)
            ax1.grid(True, alpha=0.3)
            ax1.set_xlabel('Time (s)')
            ax1.set_ylabel('Output')
            title = 'Step Response (Open Loop)' if self.current_controller == 0 else 'Step Response (Closed Loop)'
            ax1.set_title(title, fontweight='bold')
            
            _, y_impulse = signal.impulse(sys_cl, T=t)
            ax2.plot(t, y_impulse, 'b-', linewidth=2.5)
            ax2.grid(True, alpha=0.3)
            ax2.set_xlabel('Time (s)')
            ax2.set_ylabel('Output')
            title = 'Impulse Response (Open Loop)' if self.current_controller == 0 else 'Impulse Response (Closed Loop)'
            ax2.set_title(title, fontweight='bold')
            
            omega = np.logspace(-2, 2, 300)
            w, mag, phase = signal.bode(sys_cl, omega)
            mag = np.clip(mag, -200, 200)
            
            ax3.semilogx(w, mag, 'b-', linewidth=2.5)
            ax3.grid(True, alpha=0.3, which='both')
            ax3.set_xlabel('Frequency (rad/s)')
            ax3.set_ylabel('Magnitude (dB)')
            ax3.set_title('Bode Magnitude', fontweight='bold')
            
            idx_3db = np.where(mag <= -3)[0]
            if len(idx_3db) > 0 and idx_3db[0] > 0:
                omega_3db = np.interp(-3, [mag[idx_3db[0]-1], mag[idx_3db[0]]], 
                                     [w[idx_3db[0]-1], w[idx_3db[0]]])
                ylims = ax3.get_ylim()
                ax3.plot([omega_3db, omega_3db], ylims, 'r--', linewidth=1.5)
                ax3.plot(omega_3db, -3, 'ro', markersize=8, markerfacecolor='r')
            
            ax4.semilogx(w, phase, 'b-', linewidth=2.5)
            ax4.grid(True, alpha=0.3, which='both')
            ax4.set_xlabel('Frequency (rad/s)')
            ax4.set_ylabel('Phase (degrees)')
            ax4.set_title('Bode Phase', fontweight='bold')
            ax4.set_yticks(np.arange(-180, 1, 45))
            
            ylims = ax4.get_ylim()
            for target_phase, label in [(-45, '-45°'), (-90, '-90°'), (-135, '-135°')]:
                idx = np.where(phase <= target_phase)[0]
                if len(idx) > 0 and idx[0] > 0:
                    omega_cross = np.interp(target_phase, [phase[idx[0]-1], phase[idx[0]]],
                                           [w[idx[0]-1], w[idx[0]]])
                    ax4.plot([omega_cross, omega_cross], ylims, 'r--', linewidth=1.2)
                    ax4.plot(omega_cross, target_phase, 'ro', markersize=6, markerfacecolor='r')
            
            plt.tight_layout()
            buf = io.BytesIO()
            fig.savefig(buf, format='png', dpi=100, bbox_inches='tight')
            buf.seek(0)
            img_data = base64.b64encode(buf.read()).decode()
            self.plot_image.src_base64 = img_data
            plt.close(fig)
            
            is_stable = np.all(np.real(poles_cl) < -1e-6)
            stability_str = "Stable ✓" if is_stable else "UNSTABLE ✗"
            
            cl_wn = np.abs(poles_cl[0])
            if np.abs(np.imag(poles_cl[0])) > 1e-6:
                cl_zeta = max(0, -np.real(poles_cl[0]) / np.abs(poles_cl[0]))
            else:
                cl_zeta = 1.0
            
            overshoot = 0
            settling = np.nan
            if 0 < cl_zeta < 1:
                overshoot = np.exp(-cl_zeta*np.pi/np.sqrt(1-cl_zeta**2)) * 100
                if cl_zeta * cl_wn > 0:
                    settling = 4 / (cl_zeta * cl_wn)
            elif cl_zeta >= 1 and cl_wn > 0:
                settling = 4 / (cl_zeta * cl_wn)
                overshoot = 0
            
            info_lines = [stability_str]
            info_lines.append(f"CL: ωn={cl_wn:.1f}, ζ={cl_zeta:.2f}")
            
            if self.current_controller == 1:
                Kp, Ki, Kd = controller_values
                info_lines.append(f"Kp={Kp:.2f} Ki={Ki:.2f} Kd={Kd:.2f}")
            elif self.current_controller == 2:
                K1, K2 = controller_values
                info_lines.append(f"K₁={K1:.2f} K₂={K2:.2f}")
            else:
                info_lines.append("Open Loop")
            
            if len(poles_cl) >= 2:
                if np.abs(np.imag(poles_cl[0])) > 1e-6:
                    info_lines.append(f"P: {np.real(poles_cl[0]):.2f}±j{np.abs(np.imag(poles_cl[0])):.2f}")
                else:
                    info_lines.append(f"P: {poles_cl[0]:.3f}, {poles_cl[1]:.3f}")
            
            if not np.isnan(settling):
                info_lines.append(f"OS={overshoot:.0f}% Ts={settling:.2f}s")
            
            info_text = "\n".join(info_lines)
            self.info_container.content = ft.Text(info_text, size=10, family="monospace")
            
            self.page.update()
            
        except Exception as e:
            print(f"Error: {e}")
            import traceback
            traceback.print_exc()
    
    def reset_callback(self, e):
        """Reset all parameters"""
        self.update_controls()
        self.update_plots()
    
    def export_callback(self, e):
        """Export data"""
        try:
            timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
            plant_values = self.get_plant_values()
            
            num_plant, den_plant, wn, zeta, K = self.convert_to_tf(plant_values, self.current_plant)
            
            report = f"""{'='*40}
  System Response Analysis Export
{'='*40}
Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

SYSTEM CONFIGURATION
--------------------
Plant Model: {self.plant_models[self.current_plant]}
Controller: {self.controller_types[self.current_controller]}

PLANT PARAMETERS
----------------
"""
            params = self.all_params[self.current_plant]
            for i, param in enumerate(params):
                report += f"{param['label']} = {plant_values[i]:.6g}\n"
            
            print(f"Export complete: system_response_{timestamp}")
            
        except Exception as e:
            print(f"Export error: {e}")

def main(page: ft.Page):
    page.title = "Control System Response Analyser"
    page.window.width = 1400
    page.window.height = 900
    
    app = ControlSystemApp()
    app.page = page
    
    page.add(app)

if __name__ == '__main__':
    ft.app(main, view=ft.AppView.WEB_BROWSER)
