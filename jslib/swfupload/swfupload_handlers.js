function fileQueueError(fileObj, errorCode, message)  {
    try {
        switch (errorCode) {
            case SWFUpload.QUEUE_ERROR.QUEUE_LIMIT_EXCEEDED:
                alert("You have attempted to queue too many files.\n" + (message === 0 ? "You have reached the upload limit." : "You may select " + (message > 1 ? "up to " + message + " files." : "one file.")));
                return;
            case SWFUpload.QUEUE_ERROR.FILE_EXCEEDS_SIZE_LIMIT:
                alert("The file you selected is too big.");
                this.debug("Error Code: File too big, File name: " + fileObj.name + ", File size: " + fileObj.size + ", Message: " + message);
                return;
            case SWFUpload.QUEUE_ERROR.ZERO_BYTE_FILE:
                alert("The file you selected is empty.  Please select another file.");
                this.debug("Error Code: Zero byte file, File name: " + fileObj.name + ", File size: " + fileObj.size + ", Message: " + message);
                return;
            case SWFUpload.QUEUE_ERROR.INVALID_FILETYPE:
                alert("The file you choose is not an allowed file type.");
                this.debug("Error Code: Invalid File Type, File name: " + fileObj.name + ", File size: " + fileObj.size + ", Message: " + message);
                return;
            default:
                alert("An error occurred in the upload. Try again later.");
                this.debug("Error Code: " + errorCode + ", File name: " + fileObj.name + ", File size: " + fileObj.size + ", Message: " + message);
                return;
        }
    } catch (ex) {}
}

function uploadError(fileObj, errorCode, message) {
    try {
        var txtFileName = document.getElementById("txtFileName");
        txtFileName.value = "";
        
        // Handle this error separately because we don't want to create a FileProgress element for it.
        switch (errorCode) {
            case SWFUpload.UPLOAD_ERROR.MISSING_UPLOAD_URL:
                alert("There was a configuration error.  You will not be able to upload an image at this time.");
                this.debug("Error Code: No backend file, File name: " + fileObj.name + ", Message: " + message);
                return;
            case SWFUpload.UPLOAD_ERROR.UPLOAD_LIMIT_EXCEEDED:
                alert("You may only upload one file.");
                this.debug("Error Code: Upload Limit Exceeded, File name: " + fileObj.name + ", File size: " + fileObj.size + ", Message: " + message);
                return;
            //case SWFUpload.UPLOAD_ERROR.FILE_CANCELLED:
            //case SWFUpload.UPLOAD_ERROR.UPLOAD_STOPPED:
            //    break;
        }

        fileObj.id = "singlefile";    // This makes it so FileProgress only makes a single UI element, instead of one for each file
        var progress = new FileProgress(fileObj, this.customSettings.progress_target);
        progress.setError();
        progress.toggleCancel(false);

        switch (errorCode) {
            case SWFUpload.UPLOAD_ERROR.HTTP_ERROR:
                progress.setStatus("Upload Error");
                this.debug("Error Code: HTTP Error, File name: " + fileObj.name + ", Message: " + message);
                break;
            case SWFUpload.UPLOAD_ERROR.UPLOAD_FAILED:
                progress.setStatus("Upload Failed.");
                this.debug("Error Code: Upload Failed, File name: " + fileObj.name + ", File size: " + fileObj.size + ", Message: " + message);
                break;
            case SWFUpload.UPLOAD_ERROR.IO_ERROR:
                progress.setStatus("Server (IO) Error");
                this.debug("Error Code: IO Error, File name: " + fileObj.name + ", Message: " + message);
                break;
            case SWFUpload.UPLOAD_ERROR.SECURITY_ERROR:
                progress.setStatus("Security Error");
                this.debug("Error Code: Security Error, File name: " + fileObj.name + ", Message: " + message);
                break;
            case SWFUpload.UPLOAD_ERROR.FILE_CANCELLED:
                progress.setStatus("Upload Cancelled");
                this.debug("Error Code: Upload Cancelled, File name: " + fileObj.name + ", Message: " + message);
                break;
            case SWFUpload.UPLOAD_ERROR.UPLOAD_STOPPED:
                progress.setStatus("Upload Stopped");
                this.debug("Error Code: Upload Stopped, File name: " + fileObj.name + ", Message: " + message);
                break;
            default:
                alert("An error occurred in the upload. Try again later.");
                this.debug("Error Code: " + errorCode + ", File name: " + fileObj.name + ", File size: " + fileObj.size + ", Message: " + message);
                return;
        }
    } catch (ex) { }
}

