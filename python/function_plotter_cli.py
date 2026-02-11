#!/usr/bin/env python3
"""
Function Plotter - CLI Version
Python/Matplotlib version matching the MATLAB implementation

Plots polynomial and Fourier functions with customizable parameters
Supports both slider and text input modes for coefficient manipulation
"""

import numpy as np
import matplotlib.pyplot as plt
from scipy import fftpack
from datetime import datetime
import os

class FunctionPlotter:
    def __init__(self):
        """Initialize Function Plotter"""
        # Configuration
        self.max_poly_terms = 11        # a0 to a11 (12 coefficients)
        self.max_fourier_terms = 9      # a1-a9, b1-b9 for Fourier
        
        # Default state
        self.method = 1                 # 1 = polynomial, 2 = Fourier
        self.dc = 0.0                   # DC offset for Fourier mode
        self.f0 = 1.0                   # Base frequency for Fourier mode (Hz)
        
        # Polynomial coefficients (a11, a10, ..., a1, a0)
        self.poly_coeffs = np.array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1], dtype=float)
        
        # Fourier coefficients
        self.fourier_amps_a = np.array([0, 0, 0, 0, 0, 0, 0, 0, 0], dtype=float)  # a1-a9 (cosine)
        self.fourier_amps_b = np.array([1, 0, 0, 0, 0, 0, 0, 0, 0], dtype=float)  # b1-b9 (sine)
        
        # Time parameters
        self.t_start = -1.0
        self.t_end = 1.0
        self.dt = 0.01
        self.times_user_set = False
        
    def update_time_from_f0(self):
        """Update time window based on frequency"""
        if not self.times_user_set:
            self.t_start = -1.0 / self.f0
            self.t_end = 1.0 / self.f0
    
    def evaluate_polynomial(self, t):
        """Evaluate polynomial at time points t
        P(t) = a11*t^11 + a10*t^10 + ... + a1*t + a0
        """
        result = np.zeros_like(t, dtype=float)
        for i, coeff in enumerate(self.poly_coeffs):
            power = self.max_poly_terms - i
            result += coeff * (t ** power)
        return result
    
    def evaluate_fourier(self, t):
        """Evaluate Fourier series at time points t
        y(t) = DC + Σ(a_n*cos(2πnf0*t) + b_n*sin(2πnf0*t))
        """
        result = self.dc * np.ones_like(t, dtype=float)
        for n in range(1, self.max_fourier_terms + 1):
            omega = 2 * np.pi * n * self.f0
            result += self.fourier_amps_a[n-1] * np.cos(omega * t)
            result += self.fourier_amps_b[n-1] * np.sin(omega * t)
        return result
    
    def compute_fourier_from_poly(self):
        """Compute Fourier coefficients from polynomial over the time window
        Performs DFT-based harmonic analysis
        """
        t_sample = np.arange(self.t_start, self.t_end, self.dt)
        y = self.evaluate_polynomial(t_sample)
        
        # Compute FFT
        y_fft = fftpack.fft(y)
        n_samples = len(t_sample)
        freqs = fftpack.fftfreq(n_samples, self.dt)
        
        # Extract coefficients for base frequency f0
        self.fourier_amps_a[:] = 0
        self.fourier_amps_b[:] = 0
        
        for n in range(1, min(self.max_fourier_terms + 1, len(freqs) // 2)):
            target_freq = n * self.f0
            # Find closest frequency bin
            idx = np.argmin(np.abs(freqs - target_freq))
            
            if idx < len(y_fft):
                coeff = y_fft[idx]
                # Extract magnitude and phase
                magnitude = 2 * np.abs(coeff) / n_samples
                phase = np.angle(coeff)
                
                # Convert to a_n and b_n
                self.fourier_amps_a[n-1] = magnitude * np.cos(phase)
                self.fourier_amps_b[n-1] = magnitude * np.sin(phase)
    
    def plot(self, title_suffix=""):
        """Plot the current function"""
        # Generate time vector
        t = np.arange(self.t_start, self.t_end, self.dt)
        
        # Evaluate function
        if self.method == 1:
            y = self.evaluate_polynomial(t)
            func_type = "Polynomial"
        else:
            y = self.evaluate_fourier(t)
            func_type = "Fourier Series"
        
        # Create plot
        fig, ax = plt.subplots(figsize=(10, 6))
        ax.plot(t, y, 'b-', linewidth=2, label=func_type)
        ax.grid(True, alpha=0.3)
        ax.set_xlabel('Time (s)', fontsize=11)
        ax.set_ylabel('Amplitude', fontsize=11)
        ax.set_title(f'Function Plotter - {func_type} {title_suffix}', fontsize=12, fontweight='bold')
        ax.legend()
        
        return fig, ax
    
    def get_info_string(self):
        """Generate info string about current configuration"""
        if self.method == 1:
            info = "=== Polynomial Mode ===\n"
            info += "Coefficients (a11 to a0):\n"
            for i, coeff in enumerate(self.poly_coeffs):
                power = self.max_poly_terms - i
                info += f"a{power}: {coeff:.4f}\n"
        else:
            info = "=== Fourier Series Mode ===\n"
            info += f"Base frequency f0: {self.f0:.4f} Hz\n"
            info += f"DC offset: {self.dc:.4f}\n"
            info += "Cosine coefficients (a1-a9):\n"
            for i, a in enumerate(self.fourier_amps_a):
                info += f"a{i+1}: {a:.4f}  "
                if (i + 1) % 3 == 0:
                    info += "\n"
            if len(self.fourier_amps_a) % 3 != 0:
                info += "\n"
            info += "Sine coefficients (b1-b9):\n"
            for i, b in enumerate(self.fourier_amps_b):
                info += f"b{i+1}: {b:.4f}  "
                if (i + 1) % 3 == 0:
                    info += "\n"
        
        info += f"\nTime range: [{self.t_start:.4f}, {self.t_end:.4f}] s\n"
        info += f"Time step: {self.dt:.4f} s\n"
        return info
    
    def export_plot(self, filename=None):
        """Export current plot to file"""
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            if self.method == 1:
                filename = f"polynomial_{timestamp}.png"
            else:
                filename = f"fourier_{timestamp}.png"
        
        fig, ax = self.plot()
        fig.savefig(filename, dpi=150, bbox_inches='tight')
        plt.close(fig)
        print(f"Plot exported to: {filename}")
        return filename
    
    def reset_to_defaults(self):
        """Reset all parameters to defaults"""
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


def interactive_mode():
    """Interactive command-line interface"""
    plotter = FunctionPlotter()
    
    print("=" * 60)
    print("Function Plotter - Interactive CLI Mode")
    print("=" * 60)
    
    while True:
        print("\nOptions:")
        print("  1. Switch to polynomial mode")
        print("  2. Switch to Fourier mode")
        print("  3. Set polynomial coefficients")
        print("  4. Set Fourier coefficients")
        print("  5. Set time parameters")
        print("  6. Transform (poly → Fourier)")
        print("  7. Plot current function")
        print("  8. Export plot")
        print("  9. Print info")
        print("  0. Reset to defaults")
        print("  q. Quit")
        
        choice = input("\nEnter choice: ").strip().lower()
        
        if choice == 'q':
            break
        elif choice == '1':
            plotter.method = 1
            print("Switched to polynomial mode")
        elif choice == '2':
            plotter.method = 2
            print("Switched to Fourier mode")
        elif choice == '3':
            if plotter.method != 1:
                plotter.method = 1
            print(f"Current polynomial coefficients: {plotter.poly_coeffs}")
            try:
                idx = int(input(f"Enter coefficient index (0-{plotter.max_poly_terms}): "))
                if 0 <= idx <= plotter.max_poly_terms:
                    val = float(input(f"Enter value for a{plotter.max_poly_terms - idx}: "))
                    plotter.poly_coeffs[idx] = val
                    print("Coefficient updated")
            except ValueError:
                print("Invalid input")
        elif choice == '4':
            if plotter.method != 2:
                plotter.method = 2
            print(f"Fourier mode - enter parameters")
            try:
                plotter.f0 = float(input("Base frequency f0 (Hz) [default 1.0]: ") or "1.0")
                plotter.dc = float(input("DC offset [default 0.0]: ") or "0.0")
            except ValueError:
                print("Invalid input")
        elif choice == '5':
            try:
                plotter.t_start = float(input(f"Start time [current {plotter.t_start}]: ") or str(plotter.t_start))
                plotter.t_end = float(input(f"End time [current {plotter.t_end}]: ") or str(plotter.t_end))
                plotter.dt = float(input(f"Time step [current {plotter.dt}]: ") or str(plotter.dt))
                plotter.times_user_set = True
                print("Time parameters updated")
            except ValueError:
                print("Invalid input")
        elif choice == '6':
            print("Computing Fourier coefficients from polynomial...")
            plotter.compute_fourier_from_poly()
            plotter.method = 2
            print("Transformation complete. Switched to Fourier mode.")
        elif choice == '7':
            fig, ax = plotter.plot()
            plt.tight_layout()
            plt.show()
        elif choice == '8':
            filename = input("Enter filename (or press Enter for auto): ").strip()
            plotter.export_plot(filename if filename else None)
        elif choice == '9':
            print("\n" + plotter.get_info_string())
        elif choice == '0':
            plotter.reset_to_defaults()
            print("Reset to defaults")
        else:
            print("Invalid choice")


if __name__ == '__main__':
    interactive_mode()
