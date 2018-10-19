#!/usr/bin/env python
# -*- encoding: utf-8 -*-
"""
Setuptools module for snpaas-cli
See: https://packaging.python.org/en/latest/distributing.html
"""

# Always prefer setuptools over distutils
from setuptools import setup, find_packages
# To use a consistent encoding
from codecs import open
from os import path
import re


def find_version(*file_paths):
    # Open in Latin-1 so that we avoid encoding errors.
    # Use codecs.open for Python 2 compatibility
    here = path.abspath(path.dirname(__file__))
    with open(path.join(here, *file_paths), 'r', encoding='utf-8') as f:
        version_file = f.read()
    # The version line must have the form
    # __version__ = 'ver'
    version_match = re.search(r"^__version__ = ['\"]([^'\"]*)['\"]", version_file, re.M)
    if version_match:
        return version_match.group(1)
    raise RuntimeError("Unable to find version string.")


def find_readme(f="README.md"):
    here = path.abspath(path.dirname(__file__))
    # Get the long description from the README file
    long_description = None
    with open(path.join(here, f), encoding='utf-8') as f:
      long_description = f.read()
    return long_description


setup(
    name="snpaas-cli",
    url="https://github.com/springernature/ee-snpaas-cli",
    version=find_version('snpaas_cli/snpaas.py'),
    keywords='snpaas cf bosh credhub manage deployments',
    description="Manage SNPaaS",
    long_description=find_readme(),
    author="Jose Riguera Lopez",
    author_email="jose.riguera@springernature.com",
    license='MIT',
    packages=find_packages(exclude=['docs', 'tests']),
    download_url="https://github.com/springernature/ee-snpaas-cli/releases/tag/v" + find_version('snpaas_cli/snpaas.py'),
    # Include additional files into the package
    include_package_data=True,
    # additional files need to be installed into
    data_files=[],
    # See https://pypi.python.org/pypi?%3Aaction=list_classifiers
    classifiers=[
        # How mature is this project? Common values are
        #   3 - Alpha
        #   4 - Beta
        #   5 - Production/Stable
        'Development Status :: 5 - Production/Stable',
        # Indicate who your project is intended for
        'Intended Audience :: System Administrators',
        'Topic :: System :: Systems Administration',
        # Pick your license as you wish (should match "license" above)
        'License :: OSI Approved :: MIT License',
        # Specify the Python versions you support here. In particular, ensure
        # that you indicate whether you support Python 2, Python 3 or both.
        'Programming Language :: Python :: 2.7',
        'Programming Language :: Python :: 3'
    ],
    # To provide executable scripts, use entry points in preference to the
    # "scripts" keyword. Entry points provide cross-platform support and allow
    # pip to create the appropriate form of executable for the target platform.
    entry_points={
        'console_scripts': [
            'snpaas=snpaas_cli.snpaas:main'
        ],
    }
)
