# Preprocessing of DTI Imaging Data

This repository provdies a bash script for batch processing of DTI data.
The steps in the script, briefly given below,  closely follow the preprocessing prcedure detailed in Oldham *et*.al  [^1], Deco *et*. al[^2] and [BATMAN tutorial (pdf)](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwj_8uL86OKBAxUwm1YBHZZkAwoQFnoECBMQAQ&url=https%3A%2F%2Fosf.io%2Fpm9ba%2Fdownload&usg=AOvVaw2ny6I6EJAnmb6aazFib86N&opi=89978449). The steps below correspond to the steps in the bash script.


[^1]:[S. Oldham, A. Arnatkevic Iūtė, R. E. Smith, J. Tiego, M. A. Bellgrove, A. Fornito, The efficacy of different preprocessing steps in reducing motion-related confounds in diffusion MRI connectomics. NeuroImage 222, 117252 (2020).](https://www.sciencedirect.com/science/article/pii/S1053811920307382?via%3Dihub) 
[^2]: [Gustavo Deco et al. ,Dynamical consequences of regional heterogeneity in the brain’s transcriptional landscape.Sci. Adv.7,eabf4752(2021).DOI:10.1126/sciadv.abf4752](https://www.science.org/doi/10.1126/sciadv.abf4752)



## Software needed
The DTI preprocessing needs [MRtrix](https://mrtrix.readthedocs.io/en/3.0.4/index.html) (heavily used), [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki), [ANTS](https://picsl.upenn.edu/software/ants/), and [Freesurfer](https://surfer.nmr.mgh.harvard.edu). They must be installed on your computer before analysis. Please edit the path settings at the beginning of the shell script according to the path the softwares are installed on your computer.

In the IBS heterobrainx workstation, all the necessary software is installed, and preprocessing would begin smoothly and would take nearly 2 hours for each participant to extract the fiber tracks.

## Preprocessing Steps

1. **Convert the Raw DICOM Data:**
   - Convert the raw DICOM DTI Anterior-to-Posterior (AP) and Posterior-to-Anterior (PA) datasets into MIF format (format for data in MRtrix).
   - This conversion yields AP.mif and PA.mif files along with their bval and bvec files. These files are necessary for subsequent processing. Please use *dcm2niix* program in the command line to get the bval and bvec files automatically.

2. **Denoise the Data:**
   - Apply denoising techniques to the DTI data. This step is essential for improving data quality.

3. **Obtain Mean Denoised Images:**
   - Calculate the mean denoised AP and PA images and concatenate them. This mean image is needed for subsequent processing in Step 4.

4. **DWIFSLPreproc (Diffusion-weighted Image FSL Preprocessing):**
   - Begin the `dwifslpreproc`, which is the equivalent of the `recon` step for DTI. It deals with preprocessing tasks such as eddy current-induced distortion correction, motion correction, and (optionally) susceptibility-induced distortion correction. For more information, please see [dwifslpreproc documentation](https://mrtrix.readthedocs.io/en/3.0.4/dwi_preprocessing/dwifslpreproc.html).

5. **Outlier Detection:**
   - Detect participants with more than 5% outliers in their data and reject them if necessary.

6. **Bias Correction and Mask Generation:**
   - Apply bias correction and generate a mask to restrict the analysis to the brain-only region.

7. **Constrained Spherical Deconvolution:**
   - Use the Dhollander algorithm for constrained spherical deconvolution to extract participant-specific basis functions.

8. **Finding Fiber Orientation Distribution (FOD):**
   - Calculate the Fiber Orientation Distribution to describe the distribution of fiber orientations in the brain.

9. **Normalization of FOD:**
   - Normalize the FOD for each tissue type, which is necessary for group analysis and comparisons.

10. **Coregistration of T1 Anatomy:**
    - Coregister the T1 anatomy with the DTI data to verify the anatomical correctness of the DTI scans.

11. **Generate Streamlines:**
    - Create streamlines using anatomically constrained tractography. Multiple sets of streamlines may be generated, such as 10M, 200k, and 100k, depending on visualization needs and available resources.

12. **Streamline Refinement:**
    - Refine the streamlines if necessary to improve their accuracy and alignment with the underlying anatomy.

13. **Create Connectome:**
    - Generate a connectome using [tck2connectome](https://mrtrix.readthedocs.io/en/dev/reference/commands/tck2connectome.html) from the (refined) streamlines and store the connectome as a CSV file. The ROIs in the connectome correspond to the atlas specified while creating the connectome. We use the Desikan-Killany atlas.
14. **Connectome folder**
- Move the individual connectome csv file to the connectome folder. Since, in my project I deal with brain models for individual participants

These preprocessing steps are crucial for preparing DTI data for subsequent analyses, such as connectivity analysis and visualization. It's important to follow these steps carefully to ensure the reliability and validity of the results in DTI studies.
