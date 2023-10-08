# DTI preprocessing for Tractography
# The Preprocessing in this script follows the Deco way

# This script assumes that the DTI orignal scan files are inside .../anatomy/ibsxxxx/RawDicom
# The processed files are stored in ../anatomy/ibsxxxx/DTI

#proj_folder="SeenUnSeen"
anatomy_path="/Users/heterobrainx/anatomy"
proj_raw_path=$anatomy_path
SUBJECTS_DIR="/Applications/freesurfer/7.3.2/subjects"
fsl_MNI152_template_path="/Users/heterobrainx/fsl/data/linearMNI"  
MRTRIX3_DKlabel_path="/Users/heterobrainx/mrtrix3/share/mrtrix3/labelconvert"
Connectome="/Users/heterobrainx/Connectome"  # this is where final connectome is saved


if [ ! -d $Connectome ]; then
	echo "++ Making connectome directory for the first time"
	mkdir $Connectome

	cd $Connectome
	mkdir SC_matrix          # For storing connectome
	mkdir SC_plots   # For subject wise visualization

	cd SC_matrix
	mkdir All
	mkdir Cortical
	mkdir Subcortical
	mkdir Thalamo_cortical

else
	echo "++ Connectome directory already exists"
	echo "++ Please check with the directory $Connectome"
fi

# Begin processing from the raw data folder
cd $proj_raw_path  # This is the anatomy folder if there is no project
 
# Get the participants folder names
subs=`ls -d ibs*`    
#subs="ibs0001"
echo "---------------------------------------------------------"
echo "++ The number of participants is"  `ls -d ibs* | wc -l`
echo "---------------------------------------------------------"


# Do preprocessing for each participant
for sub in $subs
do
 

 	cd $sub               # get into the participant folder
	parti_dir=`pwd`         # store the participant directory 
	parti_nifti_dir=$parti_dir/nifti #nifti directory of the participant
	
	sub_folders=`ls -d *`
	if [ ! -d "DTI" ]; then
		echo "\n++ Beginning DTI preprocessing for " $sub
		echo "\n++ Making DTI folder inside the subject folder"
		mkdir DTI 
	else
		echo "\n++ DTI folder already exists for the participant $sub. If you need fresh processing, please delete this folder and rerun the DTI script file"
	fi

cd DTI  # cd into the DTI of this participant


	########################################################
	#Step 0: Convert T1, T2 nifti to mif using mrconvert first 
	########################################################

	if [[ ! -f TI.mif ]]; then
		echo "\n++ Converting  T1 to mif format  and moving to the DTI folder of $sub."
		mrconvert ../nifti/${sub}_T1.nii.gz T1.mif  # in the original orientation (not LAS))
	else
		echo "\n++  T1.mif  already exists. Nothing to convert "
	fi

	########################################################
	#Step 1: Convert all dicom DTI to Nifti.
	#dcm2niix automatically generates bvec and bval files
	#Here we need to make sure bval and bvec files are generated properly 
	#and whose length correponds to volume numbers  
	########################################################

	if [ ! -f DTI1.nii.gz ];then
		echo "\n++ Major DTI file does not exists. Converting for $sub."
		#raw_dti_path= $anatomy_path/$sub/RawDicom/HEAD*/DTI_SMS_64DIR_2_0ISO_0002
		#cd $raw_dti_path
		
		dcm2niix -f "DTI1" -p y -z y -o .  `ls -d ../RawDicom/HEAD*/*_0002` 

		echo "\n bvec is "
		cat DTI1.bvec

		echo "\b bval is"
		cat DTI1.bval
	else
		echo "\n++ Major DTI file already exits. Nothing to convert"
	fi


	if [ ! -f DTI_PA.nii.gz ];then
		echo "\n++ Major DTI_PA file does not exists. Converting for $sub."
		#raw_dti_path= $anatomy_path/$sub/RawDicom/HEAD*/DTI_SMS_64DIR_2_0ISO_0002
		#cd $raw_dti_path
			
		if exists_in_list "$new_IBS_format" " " "$sub";then
			dcm2niix -f "DTI_PA" -p y -z y -o .  `ls -d ../RawDicom/HEAD*/series_9_PA*` 
		else
			dcm2niix -f "DTI_PA" -p y -z y -o .  `ls -d ../RawDicom/HEAD*/PA*` 
		fi
		# dcm usually does not generate bvec and bval for PA
		# so we input them  with zero values	
		
		echo "\n bvec is" 
		echo "0 0\n0 0\n0 0" > DTI_PA.bvec
		cat DTI_PA.bvec

		echo "\b bval is"
		echo "0 0" > DTI_PA.bval
		cat DTI_PA.bval

	else
		echo "\n++ Major DTI PA file already exits. Nothing to convert"
	fi

	########################################################
	## Convert Nifti,bval, bvec to mif using mrconvert
	# for mrconvert we need to install MRtrix
	# make sure we have nifti, bval and bvec ready
	########################################################
	if [[ ! -f DTI1.mif ]]; then
			if [[ -f DTI1.nii.gz && -f DTI1.bvec && DTI1.bval ]]; then
				echo "\nEnough files for converting to mif format"
				mrconvert DTI1.nii.gz DTI1.mif -fslgrad DTI1.bvec DTI1.bval
			else
				echo "\n Not enough files for converting to mif format"
				count = count+1 
			fi
	else
			echo "\nAlready done converting to mif files of DTI" 
	fi


	if [[ ! -f DTI_PA.mif ]]; then
			if [[ -f DTI_PA.nii.gz && -f DTI_PA.bvec && DTI_PA.bval ]]; then
				echo "\nEnough files for converting to mif format"
				mrconvert DTI_PA.nii.gz DTI_PA.mif -fslgrad DTI_PA.bvec DTI_PA.bval
			else
				echo "\n Not enough files for converting to mif format"
			fi
	else
		echo "\nAlready done converting to mif files for DTI_PA"
	fi
	########################################################
	# Step 2: Denosing the data after converting to mif.
	#This step is essential before any big processing
	########################################################
	if [[  ! -f DTI1_noise.mif && ! -f DTI1_noise_residual.mif  ]]; then
			if [[  -f DTI1.mif ]]; then
				echo "\n File exits for denoising. Beginning denoising "
				dwidenoise DTI1.mif DTI1_denoised.mif -noise DTI1_noise.mif
				mrcalc DTI1.mif DTI1_denoised.mif -subtract DTI1_noise_residual.mif
			else
				echo "\nDTIi.mif file does not exist for denosing. Skipping for this participant "
			fi
	else
		echo "\n++ Already done with denoising. "
	fi
	#mrview residual.mif

	########################################################
	# Step 3:  Dealing with bo images of AP, PA and concatenate 
	########################################################

	if [[ ! -f b0_pair.mif ]]; then
		if [[ -f DTI1_denoised.mif ]]; then

			# obtain mean bo image of PA
			mrconvert DTI_PA.mif -fslgrad DTI_PA.bvec DTI_PA.bval - | mrmath - mean mean_b0_PA.mif -axis 3
			# Obtain the mean bo image of AP
			dwiextract DTI1_denoised.mif  - -bzero | mrmath - mean mean_b0_AP.mif -axis 3
			#combine the two bo images
			mrcat mean_b0_AP.mif mean_b0_PA.mif -axis 3 b0_pair.mif
		else
			echo "\n++ Denoised files does not exist for this participant"
		fi
	else
		echo "\n++ Already done with bo image of AP, PA and their mean values "
	fi

	########################################################V
	# Step 4:  Putting It All Together: Preprocessing with dwipreproc
	########################################################

	if [[ ! -f DTI1_preproc.mif ]]; then

		echo "\n++ Beginning the big processsing pipeline. This would take sometime."
		dwifslpreproc  DTI1_denoised.mif DTI1_preproc.mif -nocleanup -pe_dir AP -rpe_pair -se_epi b0_pair.mif -eddy_options "--slm=linear --data_is_shelled"
	else
		echo "\n++ Big preprocessing already done for this partipant"
	fi


	cd dwifslpreproc-tmp-*
	 # as we store the outlier percentage in this folder
	########################################################
	# Step 5:  Outlier detection after preprocessing
	########################################################

	if [[ !  -f  percentageOutliers.txt ]]; then
		echo "\n++ Checking for ouliers after preprocessing"
		totalSlices=`mrinfo dwi.mif | grep Dimensions | awk '{print $6 * $8}'`
		totalOutliers=`awk '{ for(i=1;i<=NF;i++)sum+=$i } END { print sum }' dwi_post_eddy.eddy_outlier_map`

		echo "If the following number is greater than 10, you may have to discard this subject because of too much motion or corrupted slices"
		echo "scale=5; ($totalOutliers / $totalSlices * 100)/1" | bc | tee percentageOutliers.txt
		cd ..  # return back to DTI folder
	else 
		echo "\n++  Outlier percentage already computed for this participant"
		cd .. # return back to DTI folder
	fi

	########################################################
	# Step 6: Generating mask to restrict the analysis only 
	# to the brain voxels after Bias correction 
	#(as bias correction may affect the brain only mask areas) 
	# This needs installation of ANTS
	########################################################

	if [[ ! -f bias.mifi && ! -f  mask.mif ]]; then
		echo "\n++ Beginning bias correction and mask generation"
		# Bias correction
		dwibiascorrect ants DTI1_preproc.mif  DTI1_preproc_unbiased.mif -bias bias.mif
		#Mask generation
		dwi2mask DTI1_preproc_unbiased.mif mask.mif

		# This is for diagnosis purpose
		# First view the mask generated in the above steps by mrview mask.mif
		# If you find holes in the mask, then 
		# using bet2 obtain mask (while playing with threshold to get mask without holes)
		# But we generate this for comparison
		mrconvert DTI1_preproc_unbiased.mif DTI1_unbiased.nii
		bet2 DTI1_unbiased.nii DTI1_masked.nii -m -f 0.7    # play with threshold
		mrconvert DTI1_masked.nii.gz mask_fsl.nii
	else
		echo "\n++ Already done with bias correction and mask generation"
	fi

	########################################################
	# Step 7: Constrained Spherical Deconvolution
	# This step is to extract subject-specific basis function
	# from the data (just like the HRF from fMRI data).
	# We use the most widely employed 'dhollander' algorithm
	# This algorithm spits out wm.txt, gm.txt and csf.txt
	########################################################

	if [[ ! -f wm.txt && ! -f gm.txt && ! -f csf.txt  ]];then
		echo "\n++ Beginning spherical deconvolution using Hollander's algorithm"
		dwi2response dhollander DTI1_preproc_unbiased.mif wm.txt gm.txt csf.txt -voxels voxels.mif
	else
		echo "\n++ Already done with the spherical deconvolution for this participant"
	fi

	# One may view the above output txt files via shview
	# For example, shview wm.txt

	########################################################
	# Step 8: Finding FOD 
	########################################################

	if [[ ! -f wmfod.mif && ! -f gmfod.mif && ! -f csffod.mif && ! -f vf.mif ]];then
		echo "\n++ Finding FOD"
		dwi2fod msmt_csd DTI1_preproc_unbiased.mif -mask mask.mif wm.txt wmfod.mif gm.txt gmfod.mif csf.txt csffod.mif
		# Combining the FOD files to a single file for later purpose
		echo "\n ++ Combining FOD files to a single file for later purpose"
		mrconvert -coord 3 0 wmfod.mif - | mrcat csffod.mif gmfod.mif - vf.mif
	else
		echo "\n++ Already done with FOD for gm, wm and csf and combined them"
	fi

	########################################################
	# Step 9: Normaliation of fod data for each tissue type 
	# (for group analysis/comparisons this is needed)
	# Processing of T1 using FSL, freesurfer  and MRtrix
	# using 5ttgen (5 tissue type generation)
	########################################################

	if [[ ! -f 5tt_nocoreg_fsl.mif && ! -f 5tt_coreg_fs.mif ]];then
		echo "\n++ Generating 5 Tissue types in one volume "
		# FSL way
		5ttgen fsl T1.mif 5tt_nocoreg_fsl.mif
		# Freesurfer way (with nice FS LUT!!)
		5ttgen freesurfer T1.mif 5tt_nocoreg_fs.mif
	else
		echo "\n++  Already done with 5 Tissue type generation in one volume "
	fi

	########################################################
	# Step 10: Coregsitration T1 and DTI to see if DTI is anatomically correct 
	#######################################################

	if [[ ! -f gmwmSeed_coreg.mif  ]];then

		echo "\n++ Average together the B0 images from the diffusion data."

		dwiextract DTI1_preproc_unbiased.mif - -bzero | mrmath - mean mean_b0.mif -axis 3
		
		#fsl no_reg is used; for freesurfer do the similar processing
		mrconvert mean_b0.mif mean_b0.nii.gz
		mrconvert 5tt_nocoreg_fsl.mif 5tt_nocoreg_fsl.nii.gz

		# Get only the gray matter volume of T1
		fslroi 5tt_nocoreg_fsl.nii.gz 5tt_vol0.nii.gz 0 1 # Coregister
		flirt -in mean_b0.nii.gz -ref 5tt_vol0.nii.gz -interp nearestneighbour -dof 6 -omat diff2struct_fsl.mat
		# The above command gives the transformation matrix between DTI and the gray volume# as  a *.mat format which will be converted to MRtrix format astransformconvert 
		transformconvert diff2struct_fsl.mat mean_b0.nii.gz 5tt_nocoreg_fsl.nii.gz flirt_import diff2struct_mrtrix.txt
		mrtransform 5tt_nocoreg_fsl.mif -linear diff2struct_mrtrix.txt -inverse 5tt_coreg_fsl.mif
		#mrview DTI1_preproc_unbiased.mif -overlay.load 5tt_nocoreg_fsl.mif -overlay.colourmap 2 -overlay.load 5tt_coreg.mif -overlay.colourmap 1
		5tt2gmwmi 5tt_coreg_fsl.mif gmwmSeed_coreg.mif
		#mrview DTI1_preproc_unbiased.mif -overlay.load gmwmSeed_coreg.mif
	else
		echo "\n++  Already done with coregistration for this participant"
	fi

	########################################################
	# Step 11: Streamlines (Anatomically constrained tractography)  
	# tckgen 
	#######################################################

	if [[ ! -f  smallerTracks_100k.tck ]];then
		echo "\n++ Obtaining streamlines 10M, 200k and 100k "
		tckgen -act 5tt_coreg_fsl.mif -backtrack -seed_gmwmi gmwmSeed_coreg.mif -nthreads 8 -maxlength 250 -cutoff 0.06 -select 10000000 wmfod.mif tracks_10M.tck
		# hard to view all of the 10 million streamlines, so only 200000
		tckedit tracks_10M.tck -number 200k smallerTracks_200k.tck
		tckedit tracks_10M.tck -number 100k smallerTracks_100k.tck

		# View only the smaller tracks
		#mrview DTI1_preproc_unbiased.mif -tractography.load smallerTracks_200k.tck
	else
		echo "\n++ Streamlines already exits"
	fi

	########################################################
	# Step 12: Refining streamlines wiht tcksift2
	# This step is needed as it produces sift**.txt files
	# which would be used for computing connectome, the structral connectivity matrix
	#######################################################

	if [[ ! -f sift_1M.txt  ]];then
		echo "++ Refining streamlines "
		tcksift2 -act 5tt_coreg_fsl.mif -out_mu sift_mu.txt -out_coeffs sift_coeffs.txt -nthreads 20 tracks_10M.tck wmfod.mif sift_1M.txt
	else
		echo "++ Stremlines already refined "
	fi

	########################################################
	# Step 13: Structural connectome matrix 
	#######################################################

	if [[ ! -f ${sub}_parcels.mif && assignments_${sub}_parcels.csv ]];then

		echo "++ Obtaining labels for the DK atlas from the participant fs mri folder (aparc+aseg.mgz )"
		labelconvert $SUBJECTS_DIR/${sub}_fs/mri/aparc+aseg.mgz  $FREESURFER_HOME/FreeSurferColorLUT.txt $MRTRIX3_DKlabel_path/fs_default.txt ${sub}_parcels.mif

		echo "++ Making connectome for ${sub}"
		tck2connectome -symmetric -zero_diagonal -scale_invnodevol -tck_weights_in sift_1M.txt tracks_10M.tck ${sub}_parcels.mif ${sub}_parcels.csv -out_assignment assignment_${sub}_parcels.csv
		
	else
		echo "\n++ Connectome matrix and ROI label extraction already done for this participant"
	fi

	########################################################
	# Step 14: Move the connectome to the connectome folder 
	#######################################################

		#if [[  ! -f SC_matrix/{$sub}.csv  && TD_matrix/{$sub}.csv ]]; then
		if [ ! -f $Connectome/SC_matrix/All/${sub}.csv ]; then
			echo "++ Copying the connectome of $sub to $Connectome directory "
			cp ${sub}_parcels.csv $Connectome/SC_matrix/All/${sub}.csv 
			#cp ${sub}_td.csv $Connectome/TD_matrix/${sub}.csv 
		else
			echo "++ Already copied connectome and time delay matrix to the $Connectome "
		fi

	########################################################

	echo "++ ========================================================="
	echo "++ THE END of DTI processing for the participant  ${sub}"
	echo "++ ========================================================="

	cd $proj_raw_path
done

# After the anatomical connections are moved the python program below sortes out
# cortical, subcortial,thalamocortical SC,TD values and their corresponding plots

#python3 obtain_sc_mtx_and_plots.py
#python3 obtain_td_mtx_and_plots.py	

echo "++ ========================================================="
echo "++ DTI all done with; PROCEED to Modeling! " 
echo "++ ========================================================="



