    package com.insurancefraud.common.exception;


    import io.jsonwebtoken.JwtException;
    import jakarta.servlet.http.HttpServletRequest;
    import org.springframework.http.HttpStatus;
    import org.springframework.http.ResponseEntity;
    import org.springframework.security.authentication.BadCredentialsException;
    import org.springframework.web.HttpRequestMethodNotSupportedException;
    import org.springframework.web.bind.MethodArgumentNotValidException;
    import org.springframework.web.bind.annotation.ExceptionHandler;
    import org.springframework.web.bind.annotation.RestControllerAdvice;

    import java.io.IOException;
    import java.time.LocalDateTime;
    import java.util.stream.Collectors;

    import lombok.extern.slf4j.Slf4j;

    @Slf4j
    @RestControllerAdvice
    public class GlobalExceptionHandler {

        private ResponseEntity<ApiError> buildErrorResponse(
                HttpStatus status, String error,String message , HttpServletRequest request){
            ApiError apiError = new ApiError(
                    LocalDateTime.now(),
                    status.value(),
                    error,
                    message
                    ,
                    request.getRequestURI()
            );
            return new ResponseEntity<>(apiError,status);
        }

        @ExceptionHandler(UserAlreadyExistsException.class)
        public ResponseEntity<ApiError> handleUserExists(UserAlreadyExistsException ex, HttpServletRequest request) {
            return buildErrorResponse(HttpStatus.CONFLICT, "Conflict", ex.getMessage(), request);
        }
        @ExceptionHandler(AccountDeletedException.class)
        public ResponseEntity<ApiError> handleAccountDeleted(
                AccountDeletedException ex,
                HttpServletRequest request
        ){
            return buildErrorResponse(
                    HttpStatus.CONFLICT,
                    "Conflict",
                    ex.getMessage(),
                    request
            );
        }

        @ExceptionHandler(TenantNotFoundException.class)
        public ResponseEntity<ApiError> handleTenantNotFound(
                TenantNotFoundException ex,
                HttpServletRequest request
        ) {
            return buildErrorResponse(
                    HttpStatus.NOT_FOUND,
                    "Tenant Not Found",
                    ex.getMessage(),
                    request
            );
        }

        @ExceptionHandler(MethodArgumentNotValidException.class)
        public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
            String message = ex.getBindingResult()
                    .getFieldErrors()
                    .stream()
                    .map(err -> err.getField() + ": " + err.getDefaultMessage())
                    .collect(Collectors.joining(", "));

            return buildErrorResponse(HttpStatus.BAD_REQUEST, "Bad Request", message, request);
        }

        @ExceptionHandler(RoleNotFoundException.class)
        public ResponseEntity<ApiError> handleRoleNotFound(
                RoleNotFoundException ex,
                HttpServletRequest request
        ) {
            return buildErrorResponse(
                    HttpStatus.NOT_FOUND,
                    "Role Not Found",
                    ex.getMessage(),
                    request
            );
        }

        @ExceptionHandler(UserNotFoundException.class)
        public ResponseEntity<ApiError> handleUserNotFound(
                UserNotFoundException ex,
                HttpServletRequest request
        ) {
            return buildErrorResponse(
                    HttpStatus.NOT_FOUND,
                    "User Not Found",
                    ex.getMessage(),
                    request
            );
        }

        @ExceptionHandler(IllegalArgumentException.class)
        public ResponseEntity<ApiError> handleIllegalArgument(
                IllegalArgumentException ex,
                HttpServletRequest request
        ) {
            return buildErrorResponse(
                    HttpStatus.BAD_REQUEST,
                    "Bad Request",
                    ex.getMessage(),
                    request
            );
        }
        @ExceptionHandler(EmailNotVerifiedException.class)
        public ResponseEntity<ApiError> handleBadCredentials(EmailNotVerifiedException ex, HttpServletRequest request) {
            return buildErrorResponse(HttpStatus.UNAUTHORIZED, "Unauthorized",ex.getMessage() , request);
        }



        @ExceptionHandler(EmailAlreadyVerifiedException.class)
        public ResponseEntity<ApiError> handleBadCredentials(EmailAlreadyVerifiedException ex, HttpServletRequest request) {
            return buildErrorResponse(HttpStatus.CONFLICT, "Conflict", ex.getMessage(), request);
        }




        @ExceptionHandler(EmailSendFailedException.class)
        public ResponseEntity<ApiError> handleEmailSendFailed(
                EmailSendFailedException ex,
                HttpServletRequest request
        ) {
            return buildErrorResponse(
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "Email Error",
                    ex.getMessage(),
                    request
            );
        }


        @ExceptionHandler({
                JwtException.class,
                TokenExpiredException.class,
                TokenNotFoundException.class,
                TokenAlreadyRevokedException.class
        })
        public ResponseEntity<ApiError> handleTokenExceptions(Exception ex, HttpServletRequest request) {
            String errorLabel = "Security Error";
            if (ex instanceof TokenExpiredException) errorLabel = "Token Expired";
            if (ex instanceof TokenAlreadyRevokedException) errorLabel = "Token Revoked";

            return buildErrorResponse(HttpStatus.UNAUTHORIZED, errorLabel, ex.getMessage(), request);
        }



        @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
        public ResponseEntity<ApiError> handleMethodNotAllowed(HttpRequestMethodNotSupportedException ex, HttpServletRequest request) {
            return buildErrorResponse(HttpStatus.METHOD_NOT_ALLOWED, "Method Not Allowed", ex.getMessage(), request);
        }

        @ExceptionHandler(BadCredentialsException.class)
        public ResponseEntity<ApiError> handleBadCredentials(BadCredentialsException ex, HttpServletRequest request) {
            return buildErrorResponse(HttpStatus.UNAUTHORIZED, "Unauthorized", "Invalid email or password", request);
        }

        @ExceptionHandler(ResourceNotFoundException.class)
        public ResponseEntity<ApiError> handleResourceNotFound(ResourceNotFoundException ex, HttpServletRequest request) {
            return buildErrorResponse(HttpStatus.NOT_FOUND, "Resource Not Found", ex.getMessage(), request);
        }

        @ExceptionHandler(InvalidMimeTypeException.class)
        public ResponseEntity<ApiError> handleInvalidMimeType(InvalidMimeTypeException ex, HttpServletRequest request) {
            return buildErrorResponse(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "Unsupported Media Type", ex.getMessage(), request);
        }

        @ExceptionHandler(EmptyFileException.class)
        public ResponseEntity<ApiError> handleEmptyFile(EmptyFileException ex, HttpServletRequest request) {
            return buildErrorResponse(HttpStatus.BAD_REQUEST, "Bad Request", ex.getMessage(), request);
        }

        @ExceptionHandler(UnauthorizedException.class)
        public ResponseEntity<ApiError> handleUnauthorized(UnauthorizedException ex, HttpServletRequest request) {
            return buildErrorResponse(HttpStatus.UNAUTHORIZED, "Unauthorized", ex.getMessage(), request);
        }

        @ExceptionHandler(FileStorageException.class)
        public ResponseEntity<ApiError> handleFileStorageException(FileStorageException ex, HttpServletRequest request) {
            return buildErrorResponse(
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "Storage Error",
                    ex.getMessage(),
                    request
            );
        }

        @ExceptionHandler(InvalidFileException.class)
        public ResponseEntity<ApiError> handleInvalidFile(InvalidFileException ex, HttpServletRequest request) {
            return buildErrorResponse(HttpStatus.BAD_REQUEST, "Bad Request", ex.getMessage(), request);
        }

        @ExceptionHandler(IllegalStateException.class)
        public ResponseEntity<ApiError> handleIllegalState(IllegalStateException ex, HttpServletRequest request) {
            return buildErrorResponse(HttpStatus.CONFLICT, "Conflict", ex.getMessage(), request);
        }

        @ExceptionHandler(IOException.class)
        public ResponseEntity<ApiError> handleIOException(IOException ex, HttpServletRequest request) {
            return buildErrorResponse(HttpStatus.INTERNAL_SERVER_ERROR, "IO Error", ex.getMessage(), request);
        }




        @ExceptionHandler(Exception.class)
        public ResponseEntity<ApiError> handleGlobalException(
                Exception ex,
                HttpServletRequest request
        ) {
            // Log full details internally — never send to client
            log.error("Unhandled exception at {}: {}", request.getRequestURI(), ex.getMessage(), ex);
            return buildErrorResponse(
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "Internal Server Error",
                    "An unexpected error occurred. Please try again later.",
                    request
            );
        }
    }
