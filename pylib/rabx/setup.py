from setuptools import setup, find_packages
import os

file_dir = os.path.abspath(os.path.dirname(__file__))


def read_file(filename):
    filepath = os.path.join(file_dir, filename)
    return open(filepath).read()


setup(
    name='rabx',
    version='1.0',
    description=(
        'Routines for reading and writing RABX (RPC using Anything But XML)'
        'messages.'),
    long_description=read_file('README.rst'),
    author='mySociety',
    author_email='matthew@mysociety.org',
    url='https://github.com/mysociety/commonlib/tree/master/pylib/rabx',
    packages=find_packages(),
    license='MIT',
    install_requires=[
        'six',
    ],
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'License :: OSI Approved :: MIT License',
        'Intended Audience :: Developers',
        'Programming Language :: Python',
        'Programming Language :: Python :: 2',
        'Programming Language :: Python :: 3',
        'Topic :: Communications',
    ],

    zip_safe=False,  # So that easy_install doesn't make an egg
)
