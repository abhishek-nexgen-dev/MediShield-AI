import type { ComponentProps } from 'react';

import type { Icon } from './Icon';

export type SectionItem = {
  title: string;
  description: string;
};

export type IconItem = SectionItem & { icon: ComponentProps<typeof Icon>['name'] };

export const hero = {
  eyebrow: 'Intelligent Healthcare, Built Around Patients',
  headline: ['Safer Care.', 'Smarter Decisions.', 'Connected Healthcare.'],
  description:
    'MediShield AI brings hospital management, medication safety, patient monitoring, AI-assisted clinical workflows and medical records together in one connected healthcare platform.',
} as const;

export const about = {
  title: 'Building a More Connected Future for Healthcare',
  description:
    'MediShield AI is a healthcare research and development platform for doctors, nurses, hospitals and patients. We aim to reduce gaps in care, improve communication and make important clinical information easier to access when it matters.',
  mission: 'Help healthcare teams deliver safer, more coordinated care through thoughtful technology.',
  vision: 'A healthcare ecosystem where patient information follows authorized teams throughout the patient journey.',
} as const;

export const challenges: IconItem[] = [
  {
    icon: 'shield',
    title: 'Medication errors',
    description: 'Missed doses, duplicate medication and incomplete records complicate medication rounds.',
  },
  {
    icon: 'users',
    title: 'Communication gaps',
    description: 'Important information can be lost when responsibility passes between shifts.',
  },
  {
    icon: 'layers',
    title: 'Fragmented records',
    description: 'Reports and treatment history are often spread across facilities.',
  },
  {
    icon: 'clock',
    title: 'Delayed awareness',
    description: 'Changes in patient observations may reach the care team too late.',
  },
];

export const capabilities: IconItem[] = [
  {
    icon: 'hospital',
    title: 'Hospital & Patient Management',
    description: 'Organize departments, wards, staff, patient registrations and admissions.',
  },
  {
    icon: 'shield',
    title: 'Medication Safety',
    description: 'Verify patient and medication details, flag conflicts and help prevent duplicate doses.',
  },
  {
    icon: 'activity',
    title: 'Real-Time Patient Monitoring',
    description: 'Bring connected sensor readings and configurable alerts into a shared dashboard.',
  },
  {
    icon: 'sparkles',
    title: 'AI Clinical Assistant',
    description: 'Help authorized clinicians find and summarize verified information with source references.',
  },
  {
    icon: 'file',
    title: 'Digital Medical Records',
    description: 'Organize reports, prescriptions and notes. Review extracted information against its source.',
  },
  {
    icon: 'link',
    title: 'Secure QR Referrals',
    description: 'Share permitted medical history with an authorized receiving care team.',
  },
  {
    icon: 'mic',
    title: 'Smart Nursing Workflows',
    description: 'Support shift handoffs, task tracking and multilingual voice notes.',
  },
  {
    icon: 'layers',
    title: 'Predictive AI Research',
    description: 'Explore early-warning models and decision support under professional supervision.',
  },
];

export const workflow: SectionItem[] = [
  {
    title: 'Onboard Your Hospital',
    description: 'Submit hospital details for review and configure your hospital workspace.',
  },
  {
    title: 'Register Patients',
    description: 'Create patient records and manage admissions.',
  },
  {
    title: 'Coordinate Care',
    description: 'Manage prescriptions, medication verification, monitoring and clinical updates.',
  },
  {
    title: 'Continue Care',
    description: 'Prepare discharge summaries, authorized referrals and accessible patient records.',
  },
];

export const audiences: IconItem[] = [
  {
    icon: 'hospital',
    title: 'Hospitals and Administrators',
    description: 'Coordinate staff, beds and hospital operations in one workspace.',
  },
  {
    icon: 'activity',
    title: 'Doctors',
    description: 'Review patient history, reports, prescriptions and AI-assisted summaries.',
  },
  {
    icon: 'heart',
    title: 'Nurses and Ward Staff',
    description: 'Manage daily tasks, medication workflows, observations and shift handoffs.',
  },
  {
    icon: 'users',
    title: 'Patients and Caregivers',
    description: 'Access released records and manage authorized sharing.',
  },
];

export const benefits: SectionItem[] = [
  {
    title: 'Patient-first design',
    description: 'Make safety and continuity central to the care workflow.',
  },
  {
    title: 'Connected information',
    description: 'Help authorized teams find relevant clinical records.',
  },
  {
    title: 'Human-supervised AI',
    description: 'Keep licensed professionals responsible for clinical decisions.',
  },
  {
    title: 'Privacy by design',
    description: 'Prioritize role-based access, hospital data isolation, secure sharing and audit trails.',
  },
  {
    title: 'Less manual work',
    description: 'Simplify routine documentation and communication.',
  },
];

export const questions: SectionItem[] = [
  {
    title: 'What is MediShield AI?',
    description:
      'MediShield AI is a healthcare research and prototype platform focused on clinical safety, connected hospital operations and patient continuity.',
  },
  {
    title: 'Who is it designed for?',
    description:
      'MediShield AI is designed for hospitals, clinics, doctors, nurses, authorized staff, patients and caregivers.',
  },
  {
    title: 'Does MediShield AI replace doctors?',
    description:
      'The AI features support qualified healthcare professionals. Licensed clinicians retain responsibility for medical decisions.',
  },
  {
    title: 'Can patients access their records?',
    description:
      'The planned patient portal provides verified access to released records and controls for authorized sharing.',
  },
  {
    title: 'How can a hospital get started?',
    description:
      'Select Register Your Hospital to learn how hospital onboarding is planned. The Contact Us option has project contact information.',
  },
];

export const wardRooms = [
  { room: 'A-01', pulse: '82 bpm', status: 'Simulated', needsReview: false },
  { room: 'A-02', pulse: '76 bpm', status: 'Simulated', needsReview: false },
  { room: 'A-03', pulse: '—', status: 'No reading', needsReview: true },
];
