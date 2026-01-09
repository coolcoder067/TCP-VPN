const els = {
	dragAndDropZone: document.getElementById("drag-and-drop-zone"),
	dragAndDropInput: document.getElementById("drag-and-drop-input"),
	form: document.getElementById("form"),
	submitBtn: document.getElementById("generate-btn"),
	formInputElements: document.getElementsByClassName("form-item"),
	clearBtn: document.getElementById("clear-btn"),
	errorText: document.getElementById("error-text"),
	errorBox: document.getElementById("error-box"),
	errorBtn: document.getElementById("error-x-btn")
};


for (const formItem of els.formInputElements) {
	formItem.addEventListener("focus", () => {
		formItem.classList.remove("auto-filled");
	});
}

let errorHideTimeout;

const showError = (err) => {
	err = "Error: " + err;
	console.error(err);
	els.errorText.textContent = err;
	if (els.errorBox.classList.contains("show")) {
		els.errorBox.classList.remove("show");
		els.errorBox.addEventListener("transitionend", function handler(e) {
			if (e.propertyName === "bottom") {
				els.errorBox.removeEventListener("transitionend", handler);
				els.errorBox.classList.add("show");
			}
		})
	} else {
		els.errorBox.classList.add("show");
	}
	// Hide after 5 seconds
	if (errorHideTimeout) {
		clearTimeout(errorHideTimeout);
	}
	errorHideTimeout = setTimeout(() => {
		els.errorBox.classList.remove("show");
	}, 4000);
};

els.errorBtn.addEventListener("click", (e) => {
	els.errorBox.classList.remove("show");
});

const processFile = async (file) => {
	// Add to form
	const text = await file.text();
	const vars = {};
	text.split("\n").forEach(line => {
		line = line.trim();
		if (!line || line.startsWith("#")) return; // skip empty lines or comments
		const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
		if (match) {
			const [, key, value] = match;
			// remove quotes if present
			vars[key] = value.replace(/^["']|["']$/g, "");
		}
	});
	console.log(vars);
	for (const formItem of els.formInputElements) {
		if (formItem.name in vars) {
			formItem.value = vars[formItem.name];
			formItem.classList.add("auto-filled");
		}
	}

};


els.dragAndDropZone.addEventListener("drop", (e) => {
	e.preventDefault();
	const files = e.dataTransfer.files;
	if (files.length > 0) {
		console.log(`File type ${files[0].type}, dragged and dropped`);
		if (files[0].type.startsWith("text/") || ! files[0].type) {
			processFile(files[0]);
		} else {
			showError("No configuration information found");
		}
	}
});

els.dragAndDropZone.addEventListener("dragover", (e) => {
	e.preventDefault();
});

els.dragAndDropInput.addEventListener("change", (e) => {
	if (e.target.files.length > 0) {
		const file = e.target.files[0];
		console.log(`File type ${file.type}, imported manually`);
		if (file.type.startsWith("text/") || ! file.type) {
			processFile(file);
		} else {
			showError("Unsupported file type");
		}
	}
});


els.clearBtn.addEventListener("click", (e) => {
	for (const formItem of els.formInputElements) {
		formItem.value = "";
		formItem.classList.remove("auto-filled");
	}
});

els.form.addEventListener("submit", (e) => {
	e.preventDefault();
	console.log("Submit button press");
	const vars = {};
	for (const formItem of els.formInputElements) {
		if (formItem.value) {
			vars[formItem.name] = formItem.value;
		}
	}
	console.log(vars);
	const preUpScript = ``;

	const postUpScript = `
udp2raw.exe -c -l 127.0.0.1:${"WIREGUARD_PORT" in vars ? vars.WIREGUARD_PORT : "50001"} -r ${vars.ENDPOINT_ADDRESS}:${vars.ENDPOINT_PORT} -k "${vars.UDP2RAW_PWD} --cipher-mode xor --auth-mode simple
`;

	const postDownScript = ``;

	console.log(preUpScript);
	console.log(postUpScript);
	console.log(postDownScript);

	const text = `
[Interface]
PrivateKey = ${vars.USER_PRIVATE_KEY}
Address = ${vars.USER_ADDRESS}
DNS = ${"DNS_SERVERS" in vars ? vars.DNS_SERVERS : "1.1.1.1, 2606:4700:4700::1111"}
MTU = 1342

PreUp = powershell -EncodedCommand "${btoa(preUpScript)}"
PostUp = powershell -EncodedCommand "${btoa(postUpScript)}"
PostDown = powershell -EncodedCommand "${btoa(postDownScript)}"

[Peer]
PublicKey = ${vars.SERVER_PUBLIC_KEY}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 127.0.0.1:${"WIREGUARD_PORT" in vars ? vars.WIREGUARD_PORT : "50001"}
`;
	navigator.clipboard.writeText(text)	
		.then(() => {
			els.submitBtn.textContent = "Copied!";
			els.submitBtn.disabled = true;
			console.log("Copied!");
		})
		.catch(err => {
			showError("Failed to copy to clipboard");
		});
});

els.form.addEventListener("input", () => {
	els.submitBtn.textContent = "Copy Configuration";
	els.submitBtn.disabled = false;
});


els.form.addEventListener("change", () => {
	els.submitBtn.textContent = "Copy Configuration";
	els.submitBtn.disabled = false;
});


