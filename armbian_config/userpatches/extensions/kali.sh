function extension_prepare_config__docker() {
	EXTRA_IMAGE_SUFFIXES+=("-kali") # global array
	#VENDOR="Armbian_Security"
	HOST="armbian-security"
	display_alert "Target image will have Kali repository preinstalled" "${BOARD}:${RELEASE}-${BRANCH} :: ${EXTENSION}" "info"
}

function pre_customize_image__install_kali_packages(){
	display_alert "Adding gpg-key for Kali repository" "${BOARD}:${RELEASE}-${BRANCH} :: ${EXTENSION}" "info"
	run_host_command_logged curl --max-time 60 -4 -fsSL "https://archive.kali.org/archive-key.asc" "|" gpg --dearmor -o "${SDCARD}"/usr/share/keyrings/kali.gpg

	# Add sources.list
	if [[ "${DISTRIBUTION}" == "Debian" ]]; then
		display_alert "Adding sources.list for Kali." "${BOARD}:${RELEASE}-${BRANCH} :: ${EXTENSION}" "info"
		run_host_command_logged echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/kali.gpg] http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware" "|" tee "${SDCARD}"/etc/apt/sources.list.d/kali.list
		display_alert "Pinning Kali package versions to apt for consistency." "${BOARD}:${RELEASE}-${BRANCH} :: ${EXTENSION}" "info"
		run_host_command_logged cat <<- 'end' > "${SDCARD}"/etc/apt/preferences.d/kali
			Package: *
			Pin: release o=Kali
			Pin-Priority: 50
		end
	else
		exit_with_error "Unsupported distribution: ${DISTRIBUTION}"
	fi

	display_alert "Updating package lists with Kali Linux repos" "${BOARD}:${RELEASE}-${BRANCH} :: ${EXTENSION}" "info"
	do_with_retries 3 chroot_sdcard_apt_get_update

	chroot_sdcard_apt_get_install kismet

	# display_alert "Installing Top 10 Kali Linux tools" "${EXTENSION}" "info"
	# chroot_sdcard_apt_get_install kali-tools-top10
}
