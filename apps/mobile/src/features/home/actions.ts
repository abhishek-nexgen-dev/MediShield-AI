const repository = 'https://github.com/abhishek-nexgen-dev/MediShield-AI';

type ActionContent = {
  title: string;
  description: string;
  link?: { label: string; href: string };
};

export const homeActions = {
  contact: {
    title: 'Contact the project team',
    description: 'Use the project repository for general questions and collaboration. Keep patient information, records, and credentials out of public messages.',
    link: { label: 'Visit the project repository', href: repository },
  },
  'patient-portal': {
    title: 'Patient portal',
    description: 'The planned portal will let verified patients view released records and manage authorized sharing. Portal access will become available in a later milestone.',
  },
  privacy: {
    title: 'Privacy information',
    description: 'This homepage stores your theme preference in your browser. The dashboard uses fictional data. Read the security guide for the project’s planned access and privacy controls.',
    link: { label: 'Read the security guide', href: `${repository}/blob/main/security.md` },
  },
  terms: {
    title: 'Terms of use',
    description: 'MediShield AI is a research prototype for use with synthetic data. See the repository for the software licence and project status.',
    link: { label: 'View the software licence', href: `${repository}/blob/main/LICENSE` },
  },
  disclaimer: {
    title: 'Clinical disclaimer',
    description: 'MediShield AI is a research and prototype platform. Its AI and monitoring features require appropriate validation and professional oversight and are not a substitute for medical advice or emergency care.',
  },
  support: {
    title: 'Project support',
    description: 'The frequently asked questions cover prototype use and planned hospital onboarding. For technical questions, see the project documentation.',
    link: { label: 'Read the project documentation', href: repository },
  },
  team: {
    title: 'The team behind MediShield AI',
    description: 'Abhishek Gupta leads full-stack and systems architecture. Akanksha Keshri leads AI, machine learning and research. Aman Dangi leads IoT and device integration.',
    link: { label: 'Read about the team', href: `${repository}#core-team` },
  },
} satisfies Record<string, ActionContent>;

export type HomeAction = keyof typeof homeActions;

export function getHomeAction(action: HomeAction): ActionContent {
  return homeActions[action];
}
