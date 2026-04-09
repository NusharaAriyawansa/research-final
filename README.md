# Research Project - Enhancing Covert Data Exfiltration from Smartphones through mmWave FMCW Radar

This repository contains the source code for both the **sender** and **receiver** setups used in the associated research project.

## Repository Structure

- `Sender/` – Code to encode and transmit data via smartphone vibrations.  
- `Receiver/` – Code to decode received signals from the radar system.  
- `Receiver/Data/` – Directory to store the radar dataset file.  

## Getting Started

### Receiver Setup

1. Download the radar dataset file: [z.bin](https://drive.google.com/file/d/1ijZ95pm_hpTUGTXcz4DbDQeXSQO7CLpe/view?usp=sharing)  
2. Place the downloaded `z.bin` file inside the `Receiver/Data/` directory.  
3. Run the receiver code to decode the captured signals and evaluate decoding performance.  

### Sender Setup

1. Use a **smartphone that supports vibration amplitude control** (Android devices with API level 26+ recommended).  
2. Run the sender code to transmit data as vibration sequences according to the PWAM encoding scheme.  

## Notes

- The receiver pipeline uses **cross-correlation-based pulse extraction** with dynamic thresholding for symbol detection.  
- Evaluation metrics included: Bit Error Rate (BER), data rate, and decoding confidence.  
- Ensure the `z.bin` dataset is present in the correct directory before running decoding experiments.  


