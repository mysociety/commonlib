//
// mysociety_file.h:
// Various file related functions.
//
// Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
// Email: francis@mysociety.org; WWW: http://www.mysociety.org/
//
// $Id: mysociety_error.h,v 1.4 2009-09-24 22:00:29 francis Exp $
//

#include <sys/stat.h>

// Test if a file (or directory) exists
bool file_exists(const std::string& file_name) {
    struct stat file_info;
    if (stat(file_name.c_str(),&file_info) < 0) {
        return false;
    }
    return true;
}

/////////////////////////////////////////////////////////////////////
// Memory mapped files

// Wrapper for mmap.
class MemoryMappedFile {
    public:

    MemoryMappedFile() {
        this->f_h = -1;
        this->ptr = (void*)MAP_FAILED;
    }
    
    // this is done in a separate function, rather than the constructor, so
    // it does not always have to be called (e.g. when MemoryMappedFile is used
    // as a member of another class, and is optional)
    void map_file(const std::string& f_name, unsigned int f_size, bool f_write = false) {
        this->unmap_file();

        this->f_write = f_write;
        assert(this->ptr == MAP_FAILED);

        this->f_name = f_name;
        this->f_size = f_size;

        if (!this->f_write) {
            // check the file is present and the right size
            if (stat(f_name.c_str(), &this->f_stat) < 0) {
                throw Exception((boost::format("map_file: failed to stat file %s: %s") % f_name.c_str() % strerror(errno)).str());
            }
            assert((unsigned int)this->f_stat.st_size == f_size);
        }

        // map it into RAM
        this->f_h = open(f_name.c_str(), this->f_write ? (O_RDWR | O_CREAT) : O_RDONLY, 0644);
        if (this->f_h == -1) {
            throw Exception((boost::format("map_file: failed to fopen file %s: %s") % f_name % strerror(errno)).str());
        }
        if (this->f_write) {
            if (lseek(this->f_h, f_size - 1, SEEK_SET) == -1) {
                throw Exception((boost::format("map_file: failed to lseek file: %s") % strerror(errno)).str());
            }
            if (write(this->f_h, "", 1) == -1) {
                throw Exception((boost::format("map_file: failed to write byte at end of file: %s") % strerror(errno)).str());
            }
        }
        this->ptr = mmap(NULL, f_size, this->f_write ? (PROT_READ | PROT_WRITE) : PROT_READ, MAP_SHARED, this->f_h, 0);
        if (this->ptr == MAP_FAILED) {
            throw Exception((boost::format("map_file: failed to mmap file: %s") % strerror(errno)).str());
        }
    }

    void unmap_file() {
        if (this->ptr != MAP_FAILED) {
            int ret1 = msync(this->ptr, this->f_size, MS_SYNC);
            if (ret1 == -1) {
                throw Exception((boost::format("map_file: failed to msync file: %s") % strerror(errno)).str());
            }
            int ret2 = munmap(this->ptr, this->f_size);
            if (ret2 == -1) {
                throw Exception((boost::format("map_file: failed to munmap file: %s") % strerror(errno)).str());
            }
            this->ptr = MAP_FAILED;
        }
        if (this->f_h != -1) {
            close(this->f_h);
            this->f_h = -1;
        }
    }

    ~MemoryMappedFile() {
        this->unmap_file();
    }
 
    public:
    void *ptr;
    std::string f_name;
    unsigned int f_size;
    bool f_write;
    private:
    struct stat f_stat;
    int f_h;
};



